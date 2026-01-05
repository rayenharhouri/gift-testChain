// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Interfaces/IMemberRegistry.sol";

interface IGoldAccountLedger {
    function updateBalance(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) external;

    function updateBalanceFromContract(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) external;
}

contract GoldAssetToken is ERC1155, Ownable {
    using Strings for uint256;

    // Role constants
    uint256 constant ROLE_REFINER = 1 << 0;
    uint256 constant ROLE_CUSTODIAN = 1 << 2;
    uint256 constant ROLE_PLATFORM = 1 << 6;

    // Enums
    enum AssetStatus {
        REGISTERED,
        IN_VAULT,
        IN_TRANSIT,
        PLEDGED,
        BURNED,
        MISSING,
        STOLEN
    }

    enum GoldProductType {
        BAR,
        COIN,
        DUST,
        OTHER
    }

    // Structs
    struct GoldAsset {
        string tokenId;
        string serialNumber;
        string refinerName;
        uint256 weightGrams;
        uint256 fineness;
        uint256 fineWeightGrams;
        GoldProductType productType;
        bytes32 certificateHash;
        string traceabilityGIC;
        AssetStatus status;
        uint256 mintedAt;
        bool certified;
        // NEW: bind this asset permanently to a specific IGAN
        string igan;
    }

    // State variables
    IMemberRegistry public memberRegistry;
    IGoldAccountLedger public accountLedger;
    uint256 private _tokenIdCounter;

    mapping(uint256 => GoldAsset) public assets;
    mapping(bytes32 => bool) private _registeredAssets;
    mapping(uint256 => address) public assetOwner;
    mapping(string => bool) private _usedWarrants;
    mapping(string => uint256) public warrantToToken;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;

    // Events
    event AssetMinted(
        uint256 indexed tokenId,
        string serialNumber,
        string refinerName,
        uint256 weightGrams,
        uint256 fineness,
        address indexed owner,
        uint256 timestamp
    );

    event AssetBurned(
        uint256 indexed tokenId,
        string burnReason,
        address indexed finalOwner,
        address indexed authorizedBy,
        uint256 timestamp
    );

    event AssetStatusChanged(
        uint256 indexed tokenId,
        AssetStatus previousStatus,
        AssetStatus newStatus,
        string reason,
        address indexed changedBy,
        uint256 timestamp
    );

    event CustodyChanged(
        uint256 indexed tokenId,
        address indexed fromParty,
        address indexed toParty,
        string custodyType,
        uint256 timestamp
    );

    event AssetTransferred(
        uint256 indexed tokenId,
        address indexed fromIGAN,
        address indexed toIGAN,
        uint256 timestamp
    );

    event WarrantLinked(
        string indexed warrantId,
        uint256 indexed tokenId,
        address indexed owner,
        uint256 timestamp
    );

    event OwnershipUpdated(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        string reason,
        uint256 timestamp
    );

    event WhitelistUpdated(
        address indexed account,
        bool status,
        uint256 timestamp
    );

    event BlacklistUpdated(
        address indexed account,
        bool status,
        uint256 timestamp
    );

    // Modifiers
    modifier onlyRefiner() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_REFINER),
            "Not authorized: REFINER role required"
        );
        _;
    }

    modifier onlyOwnerOrCustodian(uint256 tokenId) {
        require(
            assetOwner[tokenId] == msg.sender ||
                memberRegistry.isMemberInRole(msg.sender, ROLE_CUSTODIAN),
            "Not authorized: Owner or CUSTODIAN role required"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_PLATFORM),
            "Not authorized: PLATFORM role required"
        );
        _;
    }

    // Constructor
    constructor(
        address _memberRegistry,
        address _accountLedger
    ) ERC1155("") Ownable(msg.sender) {
        memberRegistry = IMemberRegistry(_memberRegistry);
        accountLedger = IGoldAccountLedger(_accountLedger);
        _tokenIdCounter = 1;
    }

    // Core Functions

    /**
     * @dev Mint new gold asset token and credit 1 unit to IGAN in the ledger.
     * @param to Owner address (wallet that will hold the ERC1155 token).
     * @param accountId IGAN account ID to be credited (stored on the asset).
     * @param serialNumber Refiner serial number.
     * @param refinerName Refiner/manufacturer name.
     * @param weightGrams Gross weight in grams (scaled by 10^4).
     * @param fineness Gold purity (9999 = 99.99%).
     * @param productType BAR, COIN, DUST, OTHER.
     * @param certificateHash SHA-256 hash of authenticity certificate.
     * @param traceabilityGIC GIC of introducing member.
     * @param certified LBMA certification flag.
     * @param warrantId Unique warrant identifier (one-time use).
     */
    function mint(
        address to,
        string memory accountId,
        string memory serialNumber,
        string memory refinerName,
        uint256 weightGrams,
        uint256 fineness,
        GoldProductType productType,
        bytes32 certificateHash,
        string memory traceabilityGIC,
        bool certified,
        string memory warrantId
    ) external onlyRefiner returns (uint256) {
        require(to != address(0), "Invalid owner");
        require(bytes(accountId).length > 0, "Invalid accountId");

        require(!_usedWarrants[warrantId], "Warrant already used");
        _usedWarrants[warrantId] = true;

        bytes32 assetKey = _assetKey(serialNumber, refinerName);
        require(!_registeredAssets[assetKey], "Asset already registered");
        _registeredAssets[assetKey] = true;

        uint256 tokenId = _tokenIdCounter++;
        uint256 fineWeightGrams = (weightGrams * fineness) / 10000;

        assets[tokenId] = GoldAsset({
            tokenId: string(
                abi.encodePacked("GIFT-ASSET-", tokenId.toString())
            ),
            serialNumber: serialNumber,
            refinerName: refinerName,
            weightGrams: weightGrams,
            fineness: fineness,
            fineWeightGrams: fineWeightGrams,
            productType: productType,
            certificateHash: certificateHash,
            traceabilityGIC: traceabilityGIC,
            status: AssetStatus.REGISTERED,
            mintedAt: block.timestamp,
            certified: certified,
            igan: accountId
        });

        assetOwner[tokenId] = to;
        warrantToToken[warrantId] = tokenId;

        _mint(to, tokenId, 1, "");

        // Strict / coherent path: contract-whitelisted balance update.
        if (address(accountLedger) != address(0)) {
            // If GAT is configured as a balance updater, this will pass
            // GoldAccountLedger.onlyBalanceUpdater.
            accountLedger.updateBalanceFromContract(
                accountId,
                int256(1),
                "MINT",
                tokenId
            );
        }

        emit AssetMinted(
            tokenId,
            serialNumber,
            refinerName,
            weightGrams,
            fineness,
            to,
            block.timestamp
        );
        emit WarrantLinked(warrantId, tokenId, to, block.timestamp);

        return tokenId;
    }

    /**
     * @dev Burn asset permanently and debit 1 unit from the bound IGAN.
     * @param tokenId Token ID to burn.
     * @param accountId Legacy IGAN account ID param (ignored; IGAN is taken from stored asset).
     * @param burnReason Reason for burning (e.g., redeemed, melted, lost).
     *
     * NOTE: accountId is kept for backward ABI compatibility but not trusted.
     *       The actual IGAN debited comes from assets[tokenId].igan.
     */
    function burn(
        uint256 tokenId,
        string memory accountId, // kept for ABI compatibility, ignored
        string memory burnReason
    ) external onlyOwnerOrCustodian(tokenId) {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        require(
            assets[tokenId].status != AssetStatus.BURNED,
            "Asset already burned"
        );

        address finalOwner = assetOwner[tokenId];
        assets[tokenId].status = AssetStatus.BURNED;

        // Use the IGAN stored on the asset to ensure coherence.
        string memory igan = assets[tokenId].igan;

        if (address(accountLedger) != address(0)) {
            require(bytes(igan).length > 0, "Missing IGAN for asset");
            accountLedger.updateBalanceFromContract(
                igan,
                -1,
                burnReason,
                tokenId
            );
        }

        _burn(finalOwner, tokenId, 1);

        emit AssetBurned(
            tokenId,
            burnReason,
            finalOwner,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Update asset status (cannot modify BURNED assets).
     * @param tokenId Token ID.
     * @param newStatus New status.
     * @param reason Reason for status change.
     */
    function updateStatus(
        uint256 tokenId,
        AssetStatus newStatus,
        string memory reason
    ) external onlyOwnerOrCustodian(tokenId) {
        require(
            assets[tokenId].status != AssetStatus.BURNED,
            "Cannot update burned asset"
        );

        AssetStatus previousStatus = assets[tokenId].status;
        assets[tokenId].status = newStatus;

        emit AssetStatusChanged(
            tokenId,
            previousStatus,
            newStatus,
            reason,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Update custody information (off-chain interpretation).
     * @param tokenId Token ID.
     * @param toParty New custodian.
     * @param custodyType Type of custody.
     */
    function updateCustody(
        uint256 tokenId,
        address toParty,
        string memory custodyType
    ) external onlyOwnerOrCustodian(tokenId) {
        address fromParty = assetOwner[tokenId];
        emit CustodyChanged(
            tokenId,
            fromParty,
            toParty,
            custodyType,
            block.timestamp
        );
    }

    // Query Functions

    /**
     * @dev Get complete asset details.
     */
    function getAssetDetails(
        uint256 tokenId
    ) external view returns (GoldAsset memory) {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        return assets[tokenId];
    }

    /**
     * @dev Get all non-burned assets owned by address.
     *      O(n) scan across tokenId range [1, _tokenIdCounter).
     */
    function getAssetsByOwner(
        address owner
    ) external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i < _tokenIdCounter; i++) {
            if (
                assetOwner[i] == owner && assets[i].status != AssetStatus.BURNED
            ) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 1; i < _tokenIdCounter; i++) {
            if (
                assetOwner[i] == owner && assets[i].status != AssetStatus.BURNED
            ) {
                result[index] = i;
                index++;
            }
        }
        return result;
    }

    /**
     * @dev Check if asset is locked (PLEDGED or IN_TRANSIT).
     */
    function isAssetLocked(uint256 tokenId) external view returns (bool) {
        AssetStatus status = assets[tokenId].status;
        return
            status == AssetStatus.PLEDGED || status == AssetStatus.IN_TRANSIT;
    }

    /**
     * @dev Verify certificate hash.
     */
    function verifyCertificate(
        uint256 tokenId,
        bytes32 certificateHash
    ) external view returns (bool) {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        return assets[tokenId].certificateHash == certificateHash;
    }

    // Internal Functions

    /**
     * @dev Generate composite key for duplicate prevention.
     */
    function _assetKey(
        string memory serialNumber,
        string memory refinerName
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(serialNumber, refinerName));
    }

    /**
     * @dev Override URI for metadata.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        return string(abi.encodePacked("ipfs://", assets[tokenId].tokenId));
    }

    /**
     * @dev Force transfer for compliance (PLATFORM only).
     *      Bypasses whitelist/blacklist, but still respects PLEDGED/IN_TRANSIT
     *      logic via the overridden _update hook.
     */
    function forceTransfer(
        uint256 tokenId,
        address from,
        address to,
        string memory reason
    ) external onlyAdmin {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        require(assetOwner[tokenId] == from, "Invalid from address");
        require(to != address(0), "Invalid to address");
        require(assets[tokenId].status != AssetStatus.BURNED, "Asset burned");

        _safeTransferFrom(from, to, tokenId, 1, "");

        emit OwnershipUpdated(tokenId, from, to, reason, block.timestamp);
    }

    /**
     * @dev Add address to whitelist (admin only).
     */
    function addToWhitelist(address account) external onlyAdmin {
        whitelist[account] = true;
        emit WhitelistUpdated(account, true, block.timestamp);
    }

    /**
     * @dev Remove address from whitelist (admin only).
     */
    function removeFromWhitelist(address account) external onlyAdmin {
        whitelist[account] = false;
        emit WhitelistUpdated(account, false, block.timestamp);
    }

    /**
     * @dev Add address to blacklist (admin only).
     */
    function addToBlacklist(address account) external onlyAdmin {
        blacklist[account] = true;
        emit BlacklistUpdated(account, true, block.timestamp);
    }

    /**
     * @dev Remove address from blacklist (admin only).
     */
    function removeFromBlacklist(address account) external onlyAdmin {
        blacklist[account] = false;
        emit BlacklistUpdated(account, false, block.timestamp);
    }

    /**
     * @dev Check if warrant is used.
     */
    function isWarrantUsed(
        string memory warrantId
    ) external view returns (bool) {
        return _usedWarrants[warrantId];
    }

    /**
     * @dev Get token by warrant.
     */
    function getTokenByWarrant(
        string memory warrantId
    ) external view returns (uint256) {
        require(_usedWarrants[warrantId], "Warrant not used");
        return warrantToToken[warrantId];
    }

    /**
     * @dev Override transfer to enforce whitelist/blacklist, keep assetOwner in sync,
     *      and emit business OwnershipUpdated on normal transfers.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        bool isNormalTransfer = (from != address(0) && to != address(0));
        bool isForceTransfer = false;

        if (isNormalTransfer) {
            isForceTransfer = memberRegistry.isMemberInRole(
                msg.sender,
                ROLE_PLATFORM
            );

            if (!isForceTransfer) {
                require(
                    whitelist[from] && whitelist[to],
                    "Transfer not whitelisted"
                );
                require(
                    !blacklist[from] && !blacklist[to],
                    "Address blacklisted"
                );
            }
        }

        super._update(from, to, ids, values);

        // Sync business ownership mapping + emit business transfer event
        for (uint256 i = 0; i < ids.length; i++) {
            // MVP assumption: amount is 1 per asset tokenId
            if (values[i] == 1) {
                uint256 tokenId = ids[i];

                // Block transfers when the asset is locked (pledged or in transit)
                // (applies to normal transfers; mint/burn are not blocked here)
                if (isNormalTransfer) {
                    AssetStatus status = assets[tokenId].status;
                    require(
                        status != AssetStatus.PLEDGED &&
                            status != AssetStatus.IN_TRANSIT,
                        "Asset locked"
                    );
                }

                if (from == address(0) && to != address(0)) {
                    // mint
                    assetOwner[tokenId] = to;
                } else if (from != address(0) && to == address(0)) {
                    // burn
                    assetOwner[tokenId] = address(0);
                } else if (isNormalTransfer) {
                    // normal transfer
                    address prevOwner = assetOwner[tokenId];
                    assetOwner[tokenId] = to;

                    // Emit only for standard transfers (forceTransfer already emits)
                    if (!isForceTransfer) {
                        emit OwnershipUpdated(
                            tokenId,
                            prevOwner,
                            to,
                            "TRANSFER",
                            block.timestamp
                        );
                    }
                }
            }
        }
    }

    /**
     * @dev Set MemberRegistry address (contract owner only).
     */
    function setMemberRegistry(address _memberRegistry) external onlyOwner {
        require(_memberRegistry != address(0), "Invalid registry");
        memberRegistry = IMemberRegistry(_memberRegistry);
    }

    /**
     * @dev Set AccountLedger address (contract owner only).
     */
    function setAccountLedger(address _accountLedger) external onlyOwner {
        accountLedger = IGoldAccountLedger(_accountLedger);
    }
}
