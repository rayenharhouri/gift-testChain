# GIFT Blockchain - ERC1155 NFT Smart Contract Requirements

## Overview
Create an ERC1155-based smart contract for minting and managing gold assets as non-fungible tokens on the GIFT blockchain.

## Core Requirements for GoldAssetToken (ERC1155)

### 1. Token Standard
- **Standard**: ERC1155 (Multi-Token Standard)
- **Purpose**: Represent physical gold assets as NFTs
- **Token Behavior**: Each token ID = 1 unique physical gold asset (non-fungible within ERC1155)

### 2. Essential Data Structure

```solidity
struct GoldAsset {
    string tokenId;              // GIFT-ASSET-YYYY-NNNNN
    string serialNumber;         // Refiner serial number
    string refinerName;          // Refiner/manufacturer name
    uint256 weightGrams;         // Gross weight (scaled by 10^4)
    uint256 fineness;            // Purity (9999 = 99.99%)
    uint256 fineWeightGrams;     // Calculated: weightGrams × fineness / 10000
    GoldProductType productType; // BAR, COIN, DUST, OTHER
    bytes32 certificateHash;     // SHA-256 hash of authenticity cert
    string traceabilityGIC;      // GIC of introducing member
    AssetStatus status;          // REGISTERED, IN_VAULT, IN_TRANSIT, PLEDGED, BURNED
    uint256 mintedAt;            // Block timestamp
    bool certified;              // LBMA certification flag
}

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
```

### 3. Critical Functions

#### Minting
```solidity
function mint(
    address to,
    string memory tokenId,
    string memory serialNumber,
    string memory refinerName,
    uint256 weightGrams,
    uint256 fineness,
    GoldProductType productType,
    bytes32 certificateHash,
    string memory traceabilityGIC,
    bool certified
) external onlyRefiner returns (uint256)
```

**Requirements:**
- Only REFINER role can mint
- Enforce uniqueness: (serialNumber + refinerName) must be unique
- Calculate fineWeightGrams automatically
- Set initial status to REGISTERED
- Emit AssetMinted event
- Return token ID

#### Burning
```solidity
function burn(
    uint256 tokenId,
    string memory burnReason
) external onlyOwnerOrAdmin
```

**Requirements:**
- Only asset owner or admin can burn
- Set status to BURNED (irreversible)
- Emit AssetBurned event

#### Status Management
```solidity
function updateStatus(
    uint256 tokenId,
    AssetStatus newStatus,
    string memory reason
) external onlyOwnerOrCustodian
```

**Requirements:**
- Validate status transitions
- Emit AssetStatusChanged event
- Log to TransactionEventLogger

### 4. Duplicate Prevention

**Mechanism**: Composite key using (serialNumber, refinerName)

```solidity
mapping(bytes32 => bool) private _registeredAssets;

function _assetKey(string memory serialNumber, string memory refinerName) 
    private pure returns (bytes32) {
    return keccak256(abi.encodePacked(serialNumber, refinerName));
}

// In mint():
bytes32 key = _assetKey(serialNumber, refinerName);
require(!_registeredAssets[key], "Asset already registered");
_registeredAssets[key] = true;
```

### 5. Query Functions

```solidity
function getAssetDetails(uint256 tokenId) 
    external view returns (GoldAsset memory)

function getAssetsByOwner(address owner) 
    external view returns (uint256[] memory)

function isAssetLocked(uint256 tokenId) 
    external view returns (bool)

function verifyCertificate(uint256 tokenId, bytes32 certificateHash) 
    external view returns (bool)
```

### 6. Events

```solidity
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
```

### 7. Access Control Integration

**Required Roles** (from MemberRegistry):
- `ROLE_REFINER` - Can mint assets
- `ROLE_CUSTODIAN` - Can update custody
- `ROLE_PLATFORM` - Admin functions

**Authorization Pattern:**
```solidity
modifier onlyRefiner() {
    require(memberRegistry.isMemberInRole(msg.sender, ROLE_REFINER), 
            "Not authorized");
    _;
}
```

### 8. Document Verification (Merkle Root)

**Purpose**: Verify authenticity documents using Merkle root

```solidity
function verifyDocumentSet(
    uint256 tokenId,
    bytes32[] calldata merkleProof,
    bytes32 merkleRoot
) external view returns (bool)
```

**Process:**
1. Store Merkle root of document set in DocumentRegistry
2. Calculate leaf hash from certificate hash
3. Verify proof against root
4. Return true if valid

### 9. Integration Points

**Dependencies:**
- `MemberRegistry` - Authorization checks
- `GoldAccountLedger` - Update ownership on transfers
- `TransactionEventLogger` - Log all state changes
- `DocumentRegistry` - Verify document hashes

### 10. Implementation Checklist

- [ ] Inherit from ERC1155
- [ ] Implement GoldAsset struct
- [ ] Implement mint() with duplicate prevention
- [ ] Implement burn() with status management
- [ ] Implement updateStatus() with validation
- [ ] Implement query functions
- [ ] Implement all events
- [ ] Add MemberRegistry integration
- [ ] Add document verification
- [ ] Add comprehensive error handling
- [ ] Add natspec documentation
- [ ] Test all state transitions

## Next Steps

1. Create GoldAssetToken.sol with ERC1155 base
2. Implement core minting logic
3. Add duplicate prevention mechanism
4. Integrate with MemberRegistry
5. Add document verification with Merkle proofs
6. Write comprehensive tests