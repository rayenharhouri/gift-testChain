# GIFT Smart Contracts - Specification Alignment Roadmap

## 📊 Current Status vs Specification

### Legend
- ✅ **COMPLETE** - Fully implemented and tested
- 🟡 **PARTIAL** - Partially implemented, needs alignment
- ❌ **MISSING** - Not implemented yet
- 🔵 **NEW** - New requirement from spec

---

## 🔴 Phase 1 – Align Existing Contracts With Spec

### T1 – Align MemberRegistry data model with spec
**Status**: ✅ **COMPLETE**

**Current Implementation**:
- ✅ Member struct with all required fields
- ✅ User struct with all required fields
- ✅ MemberType enum (INDIVIDUAL, COMPANY, INSTITUTION)
- ✅ MemberStatus enum (PENDING, ACTIVE, SUSPENDED, TERMINATED)
- ✅ UserStatus enum (ACTIVE, INACTIVE, SUSPENDED)
- ✅ memberHash and userHash stored (no PII on-chain)

**Action**: ✅ No action needed

---

### T2 – Complete MemberRegistry functions
**Status**: ✅ **COMPLETE**

**Current Implementation**:
- ✅ registerMember
- ✅ approveMember
- ✅ suspendMember
- ✅ registerUser
- ✅ linkUserToMember
- ✅ assignRole
- ✅ revokeRole
- ✅ isMemberInRole
- ✅ getMemberStatus
- ✅ getUserStatus
- ✅ validatePermission

**Access Control**:
- ✅ Platform admin checks via ROLE_PLATFORM
- ✅ Governance checks via ROLE_GOVERNANCE
- ✅ Member admin checks implemented

**Action**: ✅ No action needed

---

### T3 – Complete MemberRegistry events
**Status**: ✅ **COMPLETE**

**Current Implementation**:
- ✅ MemberRegistered(memberGIC, memberType, registeredBy, timestamp)
- ✅ MemberApproved(memberGIC, approvedBy, timestamp)
- ✅ MemberSuspended(memberGIC, reason, suspendedBy, timestamp)
- ✅ UserRegistered(userId, userHash, registeredBy, timestamp)
- ✅ UserLinkedToMember(userId, memberGIC, linkedBy, timestamp)
- ✅ RoleAssigned(memberGIC, role, assignedBy, timestamp)
- ✅ RoleRevoked(memberGIC, role, revokedBy, timestamp)

**Action**: ✅ No action needed

---

### T4 – Align GoldAssetToken struct + enums with spec
**Status**: 🟡 **PARTIAL** - AssetStatus enum needs one value

**Current Implementation**:
- ✅ GoldAsset struct with all required fields
- ✅ serialNumber, refinerName, weightGrams, fineness
- ✅ fineWeightGrams (calculated)
- ✅ productType (BAR, COIN, DUST, OTHER)
- ✅ certificateHash, traceabilityGIC
- ✅ status, mintedAt, certified
- ✅ ERC-1155 layout (each tokenId = 1 asset)

**AssetStatus Enum**:
- ❌ REGISTERED (current) → Should be removed or mapped
- ✅ IN_VAULT
- ✅ IN_TRANSIT
- ✅ PLEDGED
- ✅ BURNED
- ✅ MISSING
- ✅ STOLEN

**Action**: 
```solidity
// Remove REGISTERED, start with IN_VAULT as initial status
enum AssetStatus {
    IN_VAULT,      // Initial status after minting
    IN_TRANSIT,
    PLEDGED,
    BURNED,
    MISSING,
    STOLEN
}
```

---

### T5 – Complete GoldAssetToken core functions
**Status**: 🟡 **PARTIAL** - Missing updatePrice, getPrice

**Current Implementation**:
- ✅ mint (with warrant ID)
- ✅ burn (with account ledger integration)
- ✅ updateStatus
- ✅ updateCustody
- ✅ getAssetDetails
- ✅ getAssetsByOwner
- ✅ verifyCertificate
- ✅ isAssetLocked
- ❌ updatePrice
- ❌ getPrice

**Action**: Add price tracking
```solidity
mapping(uint256 => uint256) public assetPrice;

function updatePrice(uint256 tokenId, uint256 newPrice) external onlyAdmin {
    assetPrice[tokenId] = newPrice;
    emit PriceUpdated(tokenId, newPrice, block.timestamp);
}

function getPrice(uint256 tokenId) external view returns (uint256) {
    return assetPrice[tokenId];
}
```

---

### T6 – Complete GoldAssetToken events
**Status**: ✅ **COMPLETE**

**Current Implementation**:
- ✅ AssetMinted(tokenId, serialNumber, refinerName, weightGrams, fineness, owner, timestamp)
- ✅ AssetBurned(tokenId, burnReason, finalOwner, authorizedBy, timestamp)
- ✅ AssetStatusChanged(tokenId, previousStatus, newStatus, reason, changedBy, timestamp)
- ✅ CustodyChanged(tokenId, fromParty, toParty, custodyType, timestamp)
- ✅ AssetTransferred(tokenId, fromIGAN, toIGAN, timestamp)
- ✅ WarrantLinked(warrantId, tokenId, owner, timestamp)
- ✅ OwnershipUpdated(tokenId, from, to, reason, timestamp)

**Action**: ✅ No action needed (add PriceUpdated if implementing T5)

---

## 🔴 Phase 2 – New Core Ledger & Warrant Logic

### T7 – Implement Warrant ID system in GoldAssetToken
**Status**: ✅ **COMPLETE**

**Current Implementation**:
- ✅ _usedWarrants mapping
- ✅ warrantToToken mapping
- ✅ mint() accepts warrantId parameter
- ✅ Duplicate warrant rejection
- ✅ WarrantLinked event emitted
- ✅ isWarrantUsed() query function
- ✅ getTokenByWarrant() query function

**Action**: ✅ No action needed

---

### T8 – Implement GoldAccountLedger data model
**Status**: ❌ **MISSING** - Needs major expansion

**Current Implementation**:
- ✅ Basic Account struct (igan, memberGIC, ownerAddress, balance, createdAt, active)
- ❌ Missing: vaultSiteId, vaultId, allocation, guarantee, purpose
- ❌ Missing: AccountBalance struct
- ❌ Missing: AssetLock struct
- ❌ Missing: AllocationMode enum
- ❌ Missing: AccountStatus enum (only has bool active)
- ❌ Missing: LockType enum

**Action**: Expand data model
```solidity
enum AllocationMode { ALLOCATED, UNALLOCATED }
enum AccountStatus { ACTIVE, SUSPENDED, CLOSED }
enum LockType { PLEDGE, MISSING, STOLEN, COMPLIANCE, TRANSIT }

struct GoldAccount {
    string igan;
    string memberGIC;
    address ownerAddress;
    string vaultSiteId;
    string vaultId;
    AllocationMode allocation;
    bool guarantee;
    string purpose;
    AccountStatus status;
    uint256 createdAt;
}

struct AccountBalance {
    uint256 totalBalance;
    uint256 availableBalance;
    uint256 lockedBalance;
}

struct AssetLock {
    uint256 tokenId;
    LockType lockType;
    string lockRef;
    uint256 lockedAt;
    bool active;
}
```

---

### T9 – Implement GoldAccountLedger functions
**Status**: ❌ **MISSING** - Needs major expansion

**Current Implementation**:
- ✅ createAccount (basic)
- ✅ updateBalance (basic)
- ✅ getAccountBalance
- ✅ getAccountDetails
- ✅ getAccountsByMember
- ❌ Missing: transferAsset
- ❌ Missing: lockAsset
- ❌ Missing: unlockAsset
- ❌ Missing: settleTransaction
- ❌ Missing: getAccountAssets
- ❌ Missing: getAccountMovements

**Action**: Implement missing functions
```solidity
function transferAsset(
    string memory fromIGAN,
    string memory toIGAN,
    uint256 tokenId,
    string memory reason,
    string memory txRef
) external;

function lockAsset(
    string memory igan,
    uint256 tokenId,
    LockType lockType,
    string memory lockRef
) external;

function unlockAsset(string memory igan, uint256 tokenId) external;

function settleTransaction(string memory txRef) external; // Only TransactionOrderBook

function getAccountAssets(string memory igan) external view returns (uint256[] memory);

function getAccountMovements(string memory igan) external view returns (Movement[] memory);
```

---

### T10 – Implement GoldAccountLedger events
**Status**: 🟡 **PARTIAL** - Missing several events

**Current Implementation**:
- ✅ AccountCreated(igan, memberGIC, ownerAddress, timestamp)
- ✅ BalanceUpdated(igan, delta, newBalance, reason, tokenId, timestamp)
- ❌ Missing: AssetTransferred
- ❌ Missing: AssetLocked
- ❌ Missing: AssetUnlocked
- ❌ Missing: AccountStatusChanged

**Action**: Add missing events
```solidity
event AssetTransferred(
    string indexed fromIGAN,
    string indexed toIGAN,
    uint256 indexed tokenId,
    string reason,
    string txRef,
    uint256 timestamp
);

event AssetLocked(
    string indexed igan,
    uint256 indexed tokenId,
    LockType lockType,
    string lockRef,
    uint256 timestamp
);

event AssetUnlocked(
    string indexed igan,
    uint256 indexed tokenId,
    uint256 timestamp
);

event AccountStatusChanged(
    string indexed igan,
    AccountStatus oldStatus,
    AccountStatus newStatus,
    uint256 timestamp
);
```

---

### T11 – Wire asset locking to asset statuses
**Status**: ❌ **MISSING**

**Current Implementation**:
- ❌ No automatic lock creation on MISSING/STOLEN status

**Action**: Add status change hooks
```solidity
// In GoldAssetToken.updateStatus()
if (newStatus == AssetStatus.MISSING) {
    accountLedger.lockAsset(igan, tokenId, LockType.MISSING, "auto");
}
if (newStatus == AssetStatus.STOLEN) {
    accountLedger.lockAsset(igan, tokenId, LockType.STOLEN, "auto");
}
```

---

## 🔴 Phase 3 – Transfer Controls & Ownership Semantics

### T12 – Add whitelist/blacklist to GoldAssetToken
**Status**: ✅ **COMPLETE**

**Current Implementation**:
- ✅ whitelist mapping
- ✅ blacklist mapping
- ✅ Enforcement in _update() hook
- ✅ addToWhitelist / removeFromWhitelist
- ✅ addToBlacklist / removeFromBlacklist
- ✅ WhitelistUpdated event
- ✅ BlacklistUpdated event

**Action**: ✅ No action needed

---

### T13 – Implement enhanced transfer events
**Status**: ✅ **COMPLETE**

**Current Implementation**:
- ✅ OwnershipUpdated(tokenId, from, to, reason, timestamp)
- ✅ Emitted on force transfers
- ✅ Reason field included

**Action**: ✅ Ensure emitted on ALL transfers (add to normal transfers if needed)

---

### T14 – Implement admin forceTransfer in GoldAssetToken
**Status**: ✅ **COMPLETE**

**Current Implementation**:
- ✅ forceTransfer(tokenId, from, to, reason)
- ✅ Restricted to ROLE_PLATFORM
- ✅ Bypasses whitelist checks
- ✅ Updates assetOwner mapping
- ✅ Emits OwnershipUpdated event

**Action**: ✅ No action needed

---

### T15 – Integrate GoldAssetToken with GoldAccountLedger
**Status**: 🟡 **PARTIAL** - Needs deeper integration

**Current Implementation**:
- ✅ Burn calls accountLedger.updateBalance
- ✅ Constructor accepts accountLedger address
- ❌ Mint doesn't update ledger balance
- ❌ Transfers don't route through ledger
- ❌ No enforcement of ledger as source of truth

**Action**: Decide ownership model and enforce
```solidity
// Option 1: Ledger is source of truth
// - All transfers MUST go through ledger.transferAsset()
// - ERC1155 transfer blocked or internal only

// Option 2: Dual tracking
// - ERC1155 owner = current holder
// - Ledger tracks account balances
// - Keep synchronized via hooks
```

---

## 🟠 Phase 4 – Vault & Logistics Contracts

### T16 – Implement VaultRegistry data model
**Status**: ❌ **MISSING** - New contract needed

**Action**: Create VaultRegistry.sol
```solidity
enum SiteStatus { ACTIVE, SUSPENDED, CLOSED }
enum VaultStatus { ACTIVE, FULL, MAINTENANCE, CLOSED }

struct VaultSite {
    string siteId;
    string location;
    string operatorGIC;
    uint256 totalCapacity;
    SiteStatus status;
    uint256 createdAt;
}

struct Vault {
    string vaultId;
    string siteId;
    uint256 capacity;
    uint256 currentOccupancy;
    VaultStatus status;
    bytes32 insuranceHash;
    uint256 lastAuditDate;
    uint256 createdAt;
}
```

---

### T17 – Implement VaultRegistry functions + events
**Status**: ❌ **MISSING**

**Action**: Implement functions
```solidity
function registerVaultSite(...) external;
function registerVault(...) external;
function updateVaultStatus(...) external;
function updateVaultSiteStatus(...) external;
function recordAudit(...) external;
function getVaultSiteDetails(...) external view;
function getVaultsInSite(...) external view;
function getVaultInventory(...) external view;
function validateVaultReference(...) external view;

// Events
event VaultSiteRegistered(...);
event VaultRegistered(...);
event VaultStatusChanged(...);
event AuditRecorded(...);
event CapacityUpdated(...);
```

---

### T18 – Implement TransactionOrderBook data model
**Status**: ❌ **MISSING** - New contract needed

**Action**: Create TransactionOrderBook.sol
```solidity
enum TransactionType { TRANSFER, PLEDGE, RELEASE, DELIVERY }
enum TransactionStatus {
    DRAFT,
    PREPARED,
    PENDING_SIGNATURES,
    SIGNED,
    EXECUTING,
    COMPLETED,
    CANCELLED,
    FAILED,
    EXPIRED
}

struct TransactionOrder {
    string txRef;
    TransactionType txType;
    string fromIGAN;
    string toIGAN;
    uint256[] tokenIds;
    TransactionStatus status;
    uint256 createdAt;
    uint256 expiresAt;
}

struct Signature {
    address signer;
    bytes signature;
    uint256 signedAt;
}
```

---

### T19 – Implement TransactionOrderBook functions + events
**Status**: ❌ **MISSING**

**Action**: Implement functions
```solidity
function createOrder(...) external returns (string memory txRef);
function prepareOrder(string memory txRef) external;
function signOrder(string memory txRef, bytes memory signature) external;
function executeOrder(string memory txRef) external;
function cancelOrder(string memory txRef) external;
function getOrderDetails(string memory txRef) external view;
function getOrderStatus(string memory txRef) external view;

// Events
event OrderCreated(...);
event OrderPrepared(...);
event OrderSigned(...);
event OrderExecuted(...);
event OrderCancelled(...);
event OrderFailed(...);
event OrderExpired(...);
```

---

## 🟠 Phase 5 – Event Logger & Documents

### T20 – Implement TransactionEventLogger
**Status**: ❌ **MISSING** - New contract needed

**Action**: Create TransactionEventLogger.sol
```solidity
enum EventType {
    ASSET_MINTED,
    ASSET_TRANSFERRED,
    ASSET_BURNED,
    ORDER_CREATED,
    ORDER_EXECUTED,
    ACCOUNT_CREATED,
    // ... etc
}

event GiftEvent(
    EventType indexed eventType,
    address indexed contractAddress,
    string indexed referenceId,
    bytes eventData,
    uint256 timestamp
);

function logEvent(EventType eventType, string memory refId, bytes memory data) external;
function logBatchEvents(...) external;
function getEventCount() external view returns (uint256);
function registerContract(address contractAddr) external;
```

---

### T21 – Implement DocumentRegistry
**Status**: ❌ **MISSING** - New contract needed

**Action**: Create DocumentRegistry.sol
```solidity
struct Document {
    string documentId;
    bytes32 documentHash;
    string documentType;
    string ownerGIC;
    uint256 createdAt;
    bool revoked;
}

struct DocumentSet {
    string setId;
    string[] documentIds;
    string purpose;
    uint256 createdAt;
}

function registerDocument(...) external;
function registerDocumentSet(...) external;
function verifyDocument(...) external view returns (bool);
function verifyDocumentSet(...) external view returns (bool);
function getDocumentDetails(...) external view;
function getDocumentSetDetails(...) external view;
function supersedeDocument(...) external;
function revokeDocument(...) external;

// Events
event DocumentRegistered(...);
event DocumentSetRegistered(...);
event DocumentVerified(...);
event DocumentSuperseded(...);
event DocumentRevoked(...);
```

---

## 📊 Summary Roadmap

### ✅ Phase 1: Align Existing Contracts (90% Complete)
- **T1-T3**: MemberRegistry ✅ COMPLETE
- **T4**: GoldAssetToken enums 🟡 Minor fix needed
- **T5**: GoldAssetToken functions 🟡 Add price tracking
- **T6**: GoldAssetToken events ✅ COMPLETE

**Estimated Effort**: 2-4 hours

---

### 🟡 Phase 2: Core Ledger & Warrant (60% Complete)
- **T7**: Warrant system ✅ COMPLETE
- **T8-T11**: GoldAccountLedger expansion ❌ Major work needed

**Estimated Effort**: 1-2 days

---

### 🟡 Phase 3: Transfer Controls (80% Complete)
- **T12-T14**: Whitelist/blacklist/force transfer ✅ COMPLETE
- **T15**: Deep integration 🟡 Design decision + implementation

**Estimated Effort**: 4-8 hours

---

### ❌ Phase 4: Vault & Logistics (0% Complete)
- **T16-T17**: VaultRegistry ❌ New contract
- **T18-T19**: TransactionOrderBook ❌ New contract

**Estimated Effort**: 2-3 days

---

### ❌ Phase 5: Event Logger & Documents (0% Complete)
- **T20**: TransactionEventLogger ❌ New contract
- **T21**: DocumentRegistry ❌ New contract

**Estimated Effort**: 1-2 days

---

## 🎯 Recommended Implementation Order

### Sprint 1 (High Priority - 2-3 days)
1. **T4**: Fix AssetStatus enum (remove REGISTERED)
2. **T5**: Add price tracking to GoldAssetToken
3. **T8-T11**: Expand GoldAccountLedger with full data model
4. **T15**: Decide and implement ownership integration model

### Sprint 2 (Medium Priority - 2-3 days)
5. **T16-T17**: Implement VaultRegistry
6. **T18-T19**: Implement TransactionOrderBook (core functions)

### Sprint 3 (Lower Priority - 1-2 days)
7. **T20**: Implement TransactionEventLogger
8. **T21**: Implement DocumentRegistry

---

## 📈 Overall Completion Status

| Phase | Tasks | Complete | Partial | Missing | % Done |
|-------|-------|----------|---------|---------|--------|
| Phase 1 | 6 | 4 | 2 | 0 | 90% |
| Phase 2 | 5 | 1 | 0 | 4 | 20% |
| Phase 3 | 4 | 3 | 1 | 0 | 85% |
| Phase 4 | 4 | 0 | 0 | 4 | 0% |
| Phase 5 | 2 | 0 | 0 | 2 | 0% |
| **TOTAL** | **21** | **8** | **3** | **10** | **~45%** |

**Current Status**: Core contracts (MemberRegistry, GoldAssetToken) are 85-90% aligned with spec. GoldAccountLedger needs expansion. Vault, OrderBook, EventLogger, and DocumentRegistry contracts are missing.

**Next Priority**: Complete GoldAccountLedger expansion (T8-T11) as it's the foundation for transfer logic.
