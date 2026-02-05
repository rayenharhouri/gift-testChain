// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IGoldAccountLedger} from "./Interfaces/IGoldAccountLedger.sol";
import "./Interfaces/IMemberRegistry.sol";

contract GoldAssetToken is ERC1155, Ownable {
    using Strings for uint256;

    // Role constants aligned to the access matrix
    uint256 constant ROLE_REFINER = 1 << 0;
    uint256 constant ROLE_MINTER = 1 << 1;
    uint256 constant ROLE_VAULT = (1 << 2) | (1 << 3);
    uint256 constant ROLE_LSP = 1 << 4;
    uint256 constant ROLE_GMO = (1 << 6) | (1 << 7);

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

    // Structs
    struct GoldAsset {
        string tokenId;
        string serialNumber;
        string refinerName;
        uint256 weightGrams;
        uint256 fineness;
        uint256 fineWeightGrams;
        string productType;
        bytes32 certificateHash;
        string traceabilityGIC;
        AssetStatus status;
        uint256 mintedAt;
        bool certified;
        string igan;
    }

    // State variables
    IMemberRegistry public memberRegistry;
    IGoldAccountLedger public accountLedger;
    uint256 private _tokenIdCounter;
    bool private _inForceTransfer;

    mapping(uint256 => GoldAsset) public assets;
    mapping(bytes32 => bool) private _registeredAssets;
    mapping(uint256 => address) public assetOwner;
    mapping(string => bool) private _usedWarrants;
    mapping(string => uint256) public warrantToToken;

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

    // Modifiers
    modifier onlyRefinerOrMinter() {
        require(
            memberRegistry.isMemberInRole(
                msg.sender,
                ROLE_REFINER | ROLE_MINTER
            ),
            "Not authorized: REFINER or MINTER role required"
        );
        _;
    }

    modifier onlyAssetOperator(uint256 tokenId) {
        _requireAssetOperator(tokenId);
        _;
    }

    modifier onlyGmo() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_GMO),
            "Not authorized: GMO role required"
        );
        _;
    }

    modifier callerNotBlacklisted() {
        require(!memberRegistry.isBlacklisted(msg.sender), "Caller blacklisted");
        _;
    }

    modifier addrNotBlacklisted(address a) {
        require(!memberRegistry.isBlacklisted(a), "Address blacklisted");
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
     * @param productType Product type string, e.g. "BAR", "COIN".
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
        string memory productType,
        bytes32 certificateHash,
        string memory traceabilityGIC,
        bool certified,
        string memory warrantId
    ) external onlyRefinerOrMinter returns (uint256) {
        require(to != address(0), "Invalid owner");
        require(bytes(accountId).length > 0, "Invalid accountId");

        require(!_usedWarrants[warrantId], "Warrant already used");
        _usedWarrants[warrantId] = true;

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
    ) external onlyRefinerOrMinter {
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
    ) external onlyAssetOperator(tokenId) {
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
    ) external onlyAssetOperator(tokenId) {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        address fromParty = assetOwner[tokenId];
        emit CustodyChanged(
            tokenId,
            fromParty,
            toParty,
            custodyType,
            block.timestamp
        );

        AssetStatus previousStatus = assets[tokenId].status;
        assets[tokenId].status = AssetStatus.IN_TRANSIT;
        emit AssetStatusChanged(
            tokenId,
            previousStatus,
            AssetStatus.IN_TRANSIT,
            "CUSTODY_IN_TRANSIT",
            msg.sender,
            block.timestamp
        );
    }

    /**
     * @dev Batch update custody and mark assets as IN_TRANSIT.
     * @param tokenIds Token IDs.
     * @param toParty New custodian.
     * @param custodyType Type of custody.
     */
    function updateCustodyBatch(
        uint256[] memory tokenIds,
        address toParty,
        string memory custodyType
    ) external {
        require(tokenIds.length > 0, "Missing tokenIds");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(assets[tokenId].mintedAt != 0, "Asset does not exist");
            _requireAssetOperator(tokenId);

            address fromParty = assetOwner[tokenId];
            emit CustodyChanged(
                tokenId,
                fromParty,
                toParty,
                custodyType,
                block.timestamp
            );

            AssetStatus previousStatus = assets[tokenId].status;
            assets[tokenId].status = AssetStatus.IN_TRANSIT;
            emit AssetStatusChanged(
                tokenId,
                previousStatus,
                AssetStatus.IN_TRANSIT,
                "CUSTODY_IN_TRANSIT",
                msg.sender,
                block.timestamp
            );
        }
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
     * @dev Get asset status.
     */
    function getAssetStatus(uint256 tokenId) external view returns (AssetStatus) {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        return assets[tokenId].status;
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

    function _requireAssetOperator(uint256 tokenId) internal view {
        if (assetOwner[tokenId] == msg.sender) {
            return;
        }
        require(
            memberRegistry.isMemberInRole(
                msg.sender,
                ROLE_REFINER | ROLE_MINTER | ROLE_VAULT | ROLE_LSP
            ),
            "Not authorized: asset operator role required"
        );
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
     * @dev Override URI for metadata.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        return string(abi.encodePacked("ipfs://", assets[tokenId].tokenId));
    }
    /**
     * @dev Force transfer for compliance (GMO only).
     *      blacklist
     *      logic via the overridden _update hook.
     */
    function transferAsset(uint256 tokenId, address to)
        external
        callerNotBlacklisted
        addrNotBlacklisted(to)
        returns (bool)
    {
        require(assetOwner[tokenId] == msg.sender, "Not token owner");
        _safeTransferFrom(msg.sender, to, tokenId, 1, "");
        return true;
    }

    /**
     * @dev Force transfer for compliance (GMO only).
     *      blacklist
     *      logic via the overridden _update hook.
     */
    function forceTransfer(uint256 tokenId, address from, address to, string memory reason)
        external
        callerNotBlacklisted
        onlyGmo
    {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        require(assetOwner[tokenId] == from, "Invalid from address");
        require(to != address(0), "Invalid to address");
        require(assets[tokenId].status != AssetStatus.BURNED, "Asset burned");

        _inForceTransfer = true;
        _safeTransferFrom(from, to, tokenId, 1, "");
        _inForceTransfer = false;

        emit OwnershipUpdated(tokenId, from, to, reason, block.timestamp);
    }

    /**
     * @dev Add address to blacklist (admin only).
     */
    function addToBlacklist(address account) external onlyGmo {
        memberRegistry.isBlacklisted(account);
    }

    /**
     * @dev Remove address from blacklist (admin only).
     */
    function removeFromBlacklist(address account) external onlyGmo {
        memberRegistry.isBlacklisted(account);
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
                ROLE_GMO
            );

            if (!isForceTransfer) {
                require(
                    !memberRegistry.isBlacklisted(from) &&
                        !memberRegistry.isBlacklisted(to),
                    "Address blacklisted"
                );
            }
        }

        super._update(from, to, ids, values);

        // Sync business ownership mapping + emit business transfer event
        for (uint256 i = 0; i < ids.length; i++) {
            if (from != address(0))
                require(
                    !memberRegistry.isBlacklisted(from),
                    "Address blacklisted"
                );
            if (to != address(0))
                require(
                    !memberRegistry.isBlacklisted(to),
                    "Address blacklisted"
                );
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
