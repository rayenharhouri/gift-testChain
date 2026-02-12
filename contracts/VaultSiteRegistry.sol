// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces/IMemberRegistry.sol";

/// @title VaultSiteRegistry
/// @notice On-chain registry for physical vault sites used by the GIFT platform.
/// @dev Each vault site is owned by a member (memberGIC) registered in MemberRegistry.
///      Creation is restricted to VAULT/GMO roles. All other lifecycle changes are
///      off-chain for now and can be added later as needed.
contract VaultSiteRegistry is Ownable {
    uint256 constant ROLE_VAULT = (1 << 2) | (1 << 3);
    uint256 constant ROLE_GMO = (1 << 6) | (1 << 7);
    uint8 constant MEMBER_ACTIVE = 1;

    /// @notice Immutable information and core attributes of a vault site.
    /// @dev The structure mirrors the API's vault site definition, but dynamic data
    ///      such as current utilization and valuations remain off-chain.
    struct VaultSite {
        // Identifiers
        string vaultSiteId;          // e.g. "VSZH0001"
        string vaultSiteName;        // Human-readable name
        string memberGIC;            // GIC of operating member

        // Location
        string locationName;
        string registeredAddress;
        string operationalAddress;
        string city;
        string stateOrProvince;
        string postalCode;
        string country;              
        string timezone;             // e.g. "Europe/Zurich"
        string gpsCoordinates;       // Free-form "lat,lon" string

        // Capacity (static design capacity, not live load)
        uint256 numberOfVaults;
        uint256 maximumWeightInGoldKg;

        // Operations & compliance
        string openingHours;
        string insurerName;
        string insuranceExpirationDate;
        string insuranceDocumentationSodId;
        string auditDocumentationSodId;
        string lastAuditDate;

        // Lifecycle meta
        string status;               // e.g. "active"
        uint256 createdAt;
        address createdBy;
    }

    /// @notice MemberRegistry used to validate roles and member status.
    IMemberRegistry public memberRegistry;

    /// @dev Mapping from vault_site_id to VaultSite record.
    mapping(string => VaultSite) private vaultSites;

    /// @dev List of all known vault_site_ids to support enumeration off-chain.
    string[] private vaultSiteIds;

    /// @notice Emitted whenever a new vault site is created on-chain.
    /// @param vaultSiteId Unique identifier of the vault site.
    /// @param memberGIC GIC of the operating member.
    /// @param vaultSiteName Human-readable name of the vault site.
    /// @param country ISO alpha-2 country code of the site.
    /// @param numberOfVaults Design number of individual vaults.
    /// @param maximumWeightInGoldKg Maximum gold capacity in kilograms.
    /// @param lastAuditDate Date of last audit in ISO-8601 format.
    /// @param createdBy Address that triggered the creation (platform admin).
    /// @param timestamp Block timestamp at creation.
    event VaultSiteCreated(
        string indexed vaultSiteId,
        string indexed memberGIC,
        string vaultSiteName,
        string country,
        uint256 numberOfVaults,
        uint256 maximumWeightInGoldKg,
        string lastAuditDate,
        address indexed createdBy,
        uint256 timestamp
    );

    /// @dev Restricts calls to VAULT or GMO roles in MemberRegistry.
    modifier onlyVaultOrGmo() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_VAULT) ||
                memberRegistry.isMemberInRole(msg.sender, ROLE_GMO),
            "Not authorized: VAULT or GMO role required"
        );
        _;
    }

    /// @dev Ensures the given vault_site_id is already registered.
    modifier vaultSiteExists(string memory vaultSiteId) {
        require(
            vaultSites[vaultSiteId].createdAt != 0,
            "Vault site does not exist"
        );
        _;
    }

    /// @param _memberRegistry Address of the MemberRegistry contract.
    constructor(address _memberRegistry) Ownable(msg.sender) {
        require(_memberRegistry != address(0), "Invalid MemberRegistry");
        memberRegistry = IMemberRegistry(_memberRegistry);
    }

    // -------------------------------------------------------------------------
    // Admin Functions
    // -------------------------------------------------------------------------

    /// @notice Create a new vault site associated with an ACTIVE member.
    /// @dev The API may auto-generate vaultSiteId; on-chain we require a non-empty,
    ///      unique identifier to be passed in. All arguments are minimally validated
    ///      for presence and basic format. Member must be ACTIVE in MemberRegistry.
    /// @param vaultSiteId Unique identifier for the vault site (e.g. "VSZH0001").
    /// @param vaultSiteName Human-readable name of the vault site.
    /// @param memberGIC GIC of the operating member (must be ACTIVE).
    /// @param locationName Name of the location/campus.
    /// @param registeredAddress Legal registered address of the facility.
    /// @param operationalAddress Operational address (may differ or be empty).
    /// @param city City where the vault site is located.
    /// @param stateOrProvince State or province (may be empty).
    /// @param postalCode Postal/ZIP code (may be empty).
    /// @param country ISO alpha-2 country code.
    /// @param timezone Timezone identifier (e.g. "Europe/Zurich", may be empty).
    /// @param gpsCoordinates GPS coordinates string (may be empty).
    /// @param numberOfVaults Design number of individual vaults in this site.
    /// @param maximumWeightInGoldKg Maximum designed gold capacity in kilograms.
    /// @param openingHours Informational opening hours text (may be empty).
    /// @param insurerName Name of the insurer providing coverage.
    /// @param insuranceExpirationDate Expiration date of the insurance (ISO-8601).
    /// @param insuranceDocumentationSodId SOD identifier of insurance documents.
    /// @param auditDocumentationSodId SOD identifier of audit documentation.
    /// @param lastAuditDate Date of last audit (ISO-8601).
    /// @return success Always true if the call does not revert.
    function createVaultSite(
        string memory vaultSiteId,
        string memory vaultSiteName,
        string memory memberGIC,
        string memory locationName,
        string memory registeredAddress,
        string memory operationalAddress,
        string memory city,
        string memory stateOrProvince,
        string memory postalCode,
        string memory country,
        string memory timezone,
        string memory gpsCoordinates,
        uint256 numberOfVaults,
        uint256 maximumWeightInGoldKg,
        string memory openingHours,
        string memory insurerName,
        string memory insuranceExpirationDate,
        string memory insuranceDocumentationSodId,
        string memory auditDocumentationSodId,
        string memory lastAuditDate
    ) external onlyVaultOrGmo returns (bool success) {
        require(bytes(vaultSiteId).length > 0, "Invalid vault_site_id");
        require(
            vaultSites[vaultSiteId].createdAt == 0,
            "Vault site already exists"
        );
        require(bytes(vaultSiteName).length > 0, "Invalid vault_site_name");
        require(bytes(memberGIC).length > 0, "Invalid member_gic");
        require(bytes(locationName).length > 0, "Invalid location_name");
        require(bytes(registeredAddress).length > 0, "Invalid registered_address");
        require(bytes(city).length > 0, "Invalid city");
        require(bytes(country).length == 2, "Invalid country code");
        require(numberOfVaults > 0, "number_of_vaults must be > 0");
        require(
            maximumWeightInGoldKg > 0,
            "maximum_weight_in_gold_kg must be > 0"
        );
        require(bytes(insurerName).length > 0, "Invalid insurer name");
        require(
            bytes(insuranceExpirationDate).length > 0,
            "Invalid insurance expiration"
        );
        

        // Member must exist and be ACTIVE
        uint8 status = memberRegistry.getMemberStatus(memberGIC);
        require(status == MEMBER_ACTIVE, "Member not active");

        VaultSite memory site = VaultSite({
            vaultSiteId: vaultSiteId,
            vaultSiteName: vaultSiteName,
            memberGIC: memberGIC,
            locationName: locationName,
            registeredAddress: registeredAddress,
            operationalAddress: operationalAddress,
            city: city,
            stateOrProvince: stateOrProvince,
            postalCode: postalCode,
            country: country,
            timezone: timezone,
            gpsCoordinates: gpsCoordinates,
            numberOfVaults: numberOfVaults,
            maximumWeightInGoldKg: maximumWeightInGoldKg,
            openingHours: openingHours,
            insurerName: insurerName,
            insuranceExpirationDate: insuranceExpirationDate,
            insuranceDocumentationSodId: insuranceDocumentationSodId,
            auditDocumentationSodId: auditDocumentationSodId,
            lastAuditDate: lastAuditDate,
            status: "active",
            createdAt: block.timestamp,
            createdBy: msg.sender
        });

        vaultSites[vaultSiteId] = site;
        vaultSiteIds.push(vaultSiteId);

        emit VaultSiteCreated(
            vaultSiteId,
            memberGIC,
            vaultSiteName,
            country,
            numberOfVaults,
            maximumWeightInGoldKg,
            lastAuditDate,
            msg.sender,
            block.timestamp
        );

        return true;
    }

    // -------------------------------------------------------------------------
    // Read Functions
    // -------------------------------------------------------------------------

    /// @notice Returns all stored details for a given vault site.
    /// @param vaultSiteId Identifier of the vault site.
    /// @return site The stored VaultSite struct.
    function getVaultSite(
        string memory vaultSiteId
    ) external view vaultSiteExists(vaultSiteId) returns (VaultSite memory site) {
        return vaultSites[vaultSiteId];
    }

    /// @notice Checks whether a vault site with the given ID exists.
    /// @param vaultSiteId Identifier of the vault site.
    /// @return exists True if the site is registered.
    function vaultSiteExistsView(
        string memory vaultSiteId
    ) external view returns (bool exists) {
        return vaultSites[vaultSiteId].createdAt != 0;
    }

    /// @notice Returns the list of all vault_site_ids known to the registry.
    /// @dev Intended for off-chain enumeration and indexing.
    /// @return ids Array of all registered vault_site_ids.
    function getVaultSiteIds()
        external
        view
        returns (string[] memory ids)
    {
        return vaultSiteIds;
    }
}
