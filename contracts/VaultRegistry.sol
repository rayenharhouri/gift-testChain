// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces/IMemberRegistry.sol";
import "./VaultSiteRegistry.sol";

/// @title VaultRegistry
/// @notice Registry of individual vaults belonging to vault sites in the GIFT platform.
/// @dev Each vault is associated with a vault site (vaultSiteId) stored in VaultSiteRegistry.
///      This contract handles creation and status updates. Inventory levels and valuations
///      are computed off-chain from events and other contracts (GoldAssetToken, GoldAccountLedger).
contract VaultRegistry is Ownable {
    // Role constants from MemberRegistry (matrix-aligned)
    uint256 constant ROLE_VAULT = (1 << 2) | (1 << 3);
    uint256 constant ROLE_GMO = (1 << 6) | (1 << 7);

    /// @notice Status of a vault as per the platform business rules.
    enum VaultStatus {
        USED,
        UNUSED,
        OUT_OF_SERVICE
    }

    /// @notice Static attributes and basic operational state of a vault.
    /// @dev Capacity and dimensions represent design values, not live utilization.
    struct Vault {
        // Identifiers
        string vaultId;                // e.g. "VZH001A"
        string vaultSiteId;           // Parent vault site ID, e.g. "VSZH0001"
        string memberInternalVaultId; // Member-internal ID, e.g. "ZH-VAULT-A1"

        // Capacity / design attributes
        string vaultDimensions;       // Free-form dimensions, e.g. "40-50-60"
        uint256 vaultGoldCapacityKg;  // Maximum designed gold capacity (kg)

        // Operational state
        uint256 currentWeightKg;      // Optional field, can be used by off-chain logic
        VaultStatus status;           // USED / UNUSED / OUT_OF_SERVICE
        string lastAuditDate;         // ISO-8601 string, e.g. "2025-01-15"
        string outOfServiceReason;    // Reason when OUT_OF_SERVICE (optional otherwise)

        // Lifecycle metadata
        uint256 createdAt;            // Block timestamp at creation
        address createdBy;            // Address that created the vault
    }

    /// @notice MemberRegistry used for role-based access control.
    IMemberRegistry public memberRegistry;

    /// @notice Registry of vault sites used to validate vaultSiteId.
    VaultSiteRegistry public vaultSiteRegistry;

    /// @dev Mapping from vault_id to Vault record.
    mapping(string => Vault) private vaults;

    /// @dev Mapping from vault_site_id to list of vault_ids belonging to that site.
    mapping(string => string[]) private vaultIdsBySite;

    /// @dev List of all vault_ids for off-chain enumeration and indexing.
    string[] private allVaultIds;

    /// @notice Emitted whenever a new vault is created in a vault site.
    /// @param vaultId Unique identifier of the vault.
    /// @param vaultSiteId Identifier of the parent vault site.
    /// @param memberInternalVaultId Member-internal identifier for the vault.
    /// @param vaultDimensions Human-readable dimensions of the vault.
    /// @param vaultGoldCapacityKg Maximum designed gold capacity in kilograms.
    /// @param vaultStatus Initial status of the vault.
    /// @param createdBy Address that created the vault (GMO or VAULT).
    /// @param timestamp Block timestamp at creation.
    event VaultCreated(
        string indexed vaultId,
        string indexed vaultSiteId,
        string memberInternalVaultId,
        string vaultDimensions,
        uint256 vaultGoldCapacityKg,
        VaultStatus vaultStatus,
        address indexed createdBy,
        uint256 timestamp
    );

    /// @notice Emitted when a vault's status and/or audit information is updated.
    /// @param vaultId Identifier of the vault.
    /// @param vaultSiteId Identifier of the parent vault site.
    /// @param previousStatus Status before the update.
    /// @param newStatus Status after the update.
    /// @param reason Explanation or out-of-service reason (optional).
    /// @param lastAuditDate Updated last audit date (ISO-8601 string).
    /// @param updatedBy Address that performed the update.
    /// @param timestamp Block timestamp at update.
    event VaultStatusUpdated(
        string indexed vaultId,
        string indexed vaultSiteId,
        VaultStatus previousStatus,
        VaultStatus newStatus,
        string reason,
        string lastAuditDate,
        address indexed updatedBy,
        uint256 timestamp
    );

    /// @dev Restricts calls to VAULT or GMO roles as defined in MemberRegistry.
    modifier onlyVaultOrGmo() {
        bool isVault = memberRegistry.isMemberInRole(msg.sender, ROLE_VAULT);
        bool isGmo = memberRegistry.isMemberInRole(msg.sender, ROLE_GMO);
        require(isVault || isGmo, "Not authorized");
        _;
    }

    /// @dev Ensures that the referenced vault exists in the registry.
    modifier vaultExists(string memory vaultId) {
        require(vaults[vaultId].createdAt != 0, "Vault does not exist");
        _;
    }

    /// @param _memberRegistry Address of the MemberRegistry contract.
    /// @param _vaultSiteRegistry Address of the VaultSiteRegistry contract.
    constructor(
        address _memberRegistry,
        address _vaultSiteRegistry
    ) Ownable(msg.sender) {
        require(_memberRegistry != address(0), "Invalid MemberRegistry");
        require(_vaultSiteRegistry != address(0), "Invalid VaultSiteRegistry");
        memberRegistry = IMemberRegistry(_memberRegistry);
        vaultSiteRegistry = VaultSiteRegistry(_vaultSiteRegistry);
    }

    // -------------------------------------------------------------------------
    // Admin Functions
    // -------------------------------------------------------------------------

    /// @notice Create a new vault within an existing vault site.
    /// @dev The vaultSiteId must refer to an existing site in VaultSiteRegistry.
    ///      The vaultId must be unique. Capacity and dimensions are static design
    ///      parameters; live utilization is computed off-chain.
    /// @param vaultSiteId Identifier of the parent vault site (must exist).
    /// @param vaultId Unique identifier for the vault (e.g. "VZH001A").
    /// @param memberInternalVaultId Member-internal ID for this vault.
    /// @param vaultDimensions Human-readable dimensions (e.g. "40-50-60").
    /// @param vaultGoldCapacityKg Maximum designed gold capacity in kilograms.
    /// @param initialStatus Initial status (USED, UNUSED, OUT_OF_SERVICE).
    /// @param lastAuditDate Date of last audit (ISO-8601 string, may be empty).
    /// @return success Always true if the call does not revert.
    function createVault(
        string memory vaultSiteId,
        string memory vaultId,
        string memory memberInternalVaultId,
        string memory vaultDimensions,
        uint256 vaultGoldCapacityKg,
        VaultStatus initialStatus,
        string memory lastAuditDate
    ) external onlyVaultOrGmo returns (bool success) {
        require(bytes(vaultSiteId).length > 0, "Invalid vault_site_id");
        require(
            vaultSiteRegistry.vaultSiteExistsView(vaultSiteId),
            "Vault site does not exist"
        );

        require(bytes(vaultId).length > 0, "Invalid vault_id");
        require(vaults[vaultId].createdAt == 0, "Vault already exists");

        require(bytes(memberInternalVaultId).length > 0, "Invalid internal id");
        require(bytes(vaultDimensions).length > 0, "Invalid dimensions");
        require(vaultGoldCapacityKg > 0, "Invalid capacity");

        Vault memory v = Vault({
            vaultId: vaultId,
            vaultSiteId: vaultSiteId,
            memberInternalVaultId: memberInternalVaultId,
            vaultDimensions: vaultDimensions,
            vaultGoldCapacityKg: vaultGoldCapacityKg,
            currentWeightKg: 0,
            status: initialStatus,
            lastAuditDate: lastAuditDate,
            outOfServiceReason: "",
            createdAt: block.timestamp,
            createdBy: msg.sender
        });

        vaults[vaultId] = v;
        vaultIdsBySite[vaultSiteId].push(vaultId);
        allVaultIds.push(vaultId);

        emit VaultCreated(
            vaultId,
            vaultSiteId,
            memberInternalVaultId,
            vaultDimensions,
            vaultGoldCapacityKg,
            initialStatus,
            msg.sender,
            block.timestamp
        );

        return true;
    }

    /// @notice Update the status and optionally the audit date of a vault.
    /// @dev Reason is primarily used when marking a vault OUT_OF_SERVICE, but can
    ///      also be used for audit notes on other status changes. If lastAuditDate
    ///      is non-empty, it overwrites the stored lastAuditDate.
    /// @param vaultId Identifier of the vault to update.
    /// @param newStatus New status for the vault.
    /// @param reason Explanation or out-of-service reason (optional).
    /// @param lastAuditDate Updated last audit date (ISO-8601 string, optional).
    /// @return success Always true if the call does not revert.
    function updateVaultStatus(
        string memory vaultId,
        VaultStatus newStatus,
        string memory reason,
        string memory lastAuditDate
    ) external onlyVaultOrGmo vaultExists(vaultId) returns (bool success) {
        Vault storage v = vaults[vaultId];

        VaultStatus previousStatus = v.status;
        v.status = newStatus;

        if (newStatus == VaultStatus.OUT_OF_SERVICE) {
            // When vault is out of service, reason describes why.
            v.outOfServiceReason = reason;
        } else {
            // For USED/UNUSED, keep or clear reason depending on input.
            if (bytes(reason).length > 0) {
                v.outOfServiceReason = reason;
            } else {
                v.outOfServiceReason = "";
            }
        }

        if (bytes(lastAuditDate).length > 0) {
            v.lastAuditDate = lastAuditDate;
        }

        emit VaultStatusUpdated(
            vaultId,
            v.vaultSiteId,
            previousStatus,
            newStatus,
            reason,
            v.lastAuditDate,
            msg.sender,
            block.timestamp
        );

        return true;
    }

    // -------------------------------------------------------------------------
    // Read Functions
    // -------------------------------------------------------------------------

    /// @notice Returns all stored details for a given vault.
    /// @param vaultId Identifier of the vault.
    /// @return vault The stored Vault struct.
    function getVault(
        string memory vaultId
    ) external view vaultExists(vaultId) returns (Vault memory vault) {
        return vaults[vaultId];
    }

    /// @notice Returns the list of vault IDs registered under a given vault site.
    /// @param vaultSiteId Identifier of the parent vault site.
    /// @return vaultIds Array of vault IDs belonging to the site.
    function getVaultIdsBySite(
        string memory vaultSiteId
    ) external view returns (string[] memory vaultIds) {
        return vaultIdsBySite[vaultSiteId];
    }

    /// @notice Returns the list of all vault IDs known to the registry.
    /// @dev Intended for off-chain enumeration and indexing.
    /// @return vaultIds Array of all registered vault IDs.
    function getAllVaultIds()
        external
        view
        returns (string[] memory vaultIds)
    {
        return allVaultIds;
    }

    /// @notice Checks whether a vault with the given ID exists.
    /// @param vaultId Identifier of the vault.
    /// @return exists True if the vault is registered.
    function vaultExistsView(
        string memory vaultId
    ) external view returns (bool exists) {
        return vaults[vaultId].createdAt != 0;
    }
}
