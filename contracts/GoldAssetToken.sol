// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IMemberRegistry {
    function isMemberInRole(address member, uint256 role) external view returns (bool);
    function getMemberStatus(string memory memberGIC) external view returns (uint8);
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
    }

    // State variables
    IMemberRegistry public memberRegistry;
    uint256 private _tokenIdCounter;
    
    mapping(uint256 => GoldAsset) public assets;
    mapping(bytes32 => bool) private _registeredAssets;
    mapping(uint256 => address) public assetOwner;

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

    // Modifiers
    modifier onlyRefiner() {
        require(memberRegistry.isMemberInRole(msg.sender, ROLE_REFINER), "Not authorized: REFINER role required");
        _;
    }

    modifier onlyOwnerOrCustodian(uint256 tokenId) {
        require(
            assetOwner[tokenId] == msg.sender || memberRegistry.isMemberInRole(msg.sender, ROLE_CUSTODIAN),
            "Not authorized: Owner or CUSTODIAN role required"
        );
        _;
    }

    modifier onlyAdmin() {
        require(memberRegistry.isMemberInRole(msg.sender, ROLE_PLATFORM), "Not authorized: PLATFORM role required");
        _;
    }

    // Constructor
    constructor(address _memberRegistry) ERC1155("") Ownable() {
        memberRegistry = IMemberRegistry(_memberRegistry);
        _tokenIdCounter = 1;
    }

    // Core Functions

    /**
     * @dev Mint new gold asset token
     * @param to Owner address
     * @param serialNumber Refiner serial number
     * @param refinerName Refiner/manufacturer name
     * @param weightGrams Gross weight in grams (scaled by 10^4)
     * @param fineness Gold purity (9999 = 99.99%)
     * @param productType BAR, COIN, DUST, OTHER
     * @param certificateHash SHA-256 hash of authenticity certificate
     * @param traceabilityGIC GIC of introducing member
     * @param certified LBMA certification flag
     */
    function mint(
        address to,
        string memory serialNumber,
        string memory refinerName,
        uint256 weightGrams,
        uint256 fineness,
        GoldProductType productType,
        bytes32 certificateHash,
        string memory traceabilityGIC,
        bool certified
    ) external onlyRefiner returns (uint256) {
        // Enforce uniqueness
        bytes32 assetKey = _assetKey(serialNumber, refinerName);
        require(!_registeredAssets[assetKey], "Asset already registered");
        _registeredAssets[assetKey] = true;

        // Calculate fine weight
        uint256 fineWeightGrams = (weightGrams * fineness) / 10000;

        // Create asset
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;

        GoldAsset memory asset = GoldAsset({
            tokenId: string(abi.encodePacked("GIFT-ASSET-", tokenId.toString())),
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
            certified: certified
        });

        assets[tokenId] = asset;
        assetOwner[tokenId] = to;

        // Mint ERC1155 token (amount = 1 for NFT behavior)
        _mint(to, tokenId, 1, "");

        emit AssetMinted(
            tokenId,
            serialNumber,
            refinerName,
            weightGrams,
            fineness,
            to,
            block.timestamp
        );

        return tokenId;
    }

    /**
     * @dev Burn asset permanently
     * @param tokenId Token ID to burn
     * @param burnReason Reason for burning
     */
    function burn(uint256 tokenId, string memory burnReason) external {
        require(assetOwner[tokenId] == msg.sender || msg.sender == owner(), "Not authorized");
        require(assets[tokenId].status != AssetStatus.BURNED, "Asset already burned");

        address finalOwner = assetOwner[tokenId];
        assets[tokenId].status = AssetStatus.BURNED;

        _burn(finalOwner, tokenId, 1);

        emit AssetBurned(tokenId, burnReason, finalOwner, msg.sender, block.timestamp);
    }

    /**
     * @dev Update asset status
     * @param tokenId Token ID
     * @param newStatus New status
     * @param reason Reason for status change
     */
    function updateStatus(
        uint256 tokenId,
        AssetStatus newStatus,
        string memory reason
    ) external onlyOwnerOrCustodian(tokenId) {
        require(assets[tokenId].status != AssetStatus.BURNED, "Cannot update burned asset");
        
        AssetStatus previousStatus = assets[tokenId].status;
        assets[tokenId].status = newStatus;

        emit AssetStatusChanged(tokenId, previousStatus, newStatus, reason, msg.sender, block.timestamp);
    }

    /**
     * @dev Update custody information
     * @param tokenId Token ID
     * @param toParty New custodian
     * @param custodyType Type of custody
     */
    function updateCustody(
        uint256 tokenId,
        address toParty,
        string memory custodyType
    ) external onlyOwnerOrCustodian(tokenId) {
        address fromParty = assetOwner[tokenId];
        emit CustodyChanged(tokenId, fromParty, toParty, custodyType, block.timestamp);
    }

    // Query Functions

    /**
     * @dev Get complete asset details
     */
    function getAssetDetails(uint256 tokenId) external view returns (GoldAsset memory) {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        return assets[tokenId];
    }

    /**
     * @dev Get all assets owned by address
     */
    function getAssetsByOwner(address owner) external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i < _tokenIdCounter; i++) {
            if (assetOwner[i] == owner && assets[i].status != AssetStatus.BURNED) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 1; i < _tokenIdCounter; i++) {
            if (assetOwner[i] == owner && assets[i].status != AssetStatus.BURNED) {
                result[index] = i;
                index++;
            }
        }
        return result;
    }

    /**
     * @dev Check if asset is locked
     */
    function isAssetLocked(uint256 tokenId) external view returns (bool) {
        AssetStatus status = assets[tokenId].status;
        return status == AssetStatus.PLEDGED || status == AssetStatus.IN_TRANSIT;
    }

    /**
     * @dev Verify certificate hash
     */
    function verifyCertificate(uint256 tokenId, bytes32 certificateHash) external view returns (bool) {
        return assets[tokenId].certificateHash == certificateHash;
    }

    // Internal Functions

    /**
     * @dev Generate composite key for duplicate prevention
     */
    function _assetKey(string memory serialNumber, string memory refinerName) 
        private pure returns (bytes32) {
        return keccak256(abi.encodePacked(serialNumber, refinerName));
    }

    /**
     * @dev Override URI for metadata
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(assets[tokenId].mintedAt != 0, "Asset does not exist");
        return string(abi.encodePacked("ipfs://", assets[tokenId].tokenId));
    }

    /**
     * @dev Set MemberRegistry address (admin only)
     */
    function setMemberRegistry(address _memberRegistry) external onlyOwner {
        memberRegistry = IMemberRegistry(_memberRegistry);
    }
}
