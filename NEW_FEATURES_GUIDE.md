# GIFT Smart Contracts - New Features Quick Reference

## 🆕 What's New

This guide covers the features added to complete the PoC requirements.

---

## 1. Warrant ID System

### Purpose
Link each NFT to a unique warrant document, preventing duplicate tokenization of the same warrant.

### Implementation
```solidity
// Storage
mapping(string => bool) private _usedWarrants;
mapping(string => uint256) public warrantToToken;

// Mint now requires warrantId
function mint(..., string memory warrantId) external onlyRefiner returns (uint256)
```

### Usage
```solidity
// Mint with warrant
uint256 tokenId = goldAssetToken.mint(
    owner,
    "SN123456",
    "Refiner A",
    1000000,
    9999,
    GoldProductType.BAR,
    certHash,
    "GIFTCHZZ",
    true,
    "WARRANT-2024-001"  // ← Unique warrant ID
);

// Check if warrant used
bool used = goldAssetToken.isWarrantUsed("WARRANT-2024-001");

// Get token by warrant
uint256 token = goldAssetToken.getTokenByWarrant("WARRANT-2024-001");
```

### Events
```solidity
event WarrantLinked(
    string indexed warrantId,
    uint256 indexed tokenId,
    address indexed owner,
    uint256 timestamp
);
```

---

## 2. Transfer Whitelist/Blacklist

### Purpose
Regulatory compliance - control who can send/receive gold tokens.

### Implementation
```solidity
mapping(address => bool) public whitelist;
mapping(address => bool) public blacklist;

// Enforced in _update() hook
function _update(address from, address to, ...) internal override
```

### Usage
```solidity
// Add to whitelist (PLATFORM role only)
goldAssetToken.addToWhitelist(traderAddress);

// Remove from whitelist
goldAssetToken.removeFromWhitelist(traderAddress);

// Add to blacklist
goldAssetToken.addToBlacklist(suspiciousAddress);

// Remove from blacklist
goldAssetToken.removeFromBlacklist(suspiciousAddress);

// Check status
bool isWhitelisted = goldAssetToken.whitelist(address);
bool isBlacklisted = goldAssetToken.blacklist(address);
```

### Transfer Rules
- **Normal transfers**: At least one party (from OR to) must be whitelisted
- **Blacklist**: Neither party can be blacklisted
- **Admin bypass**: PLATFORM role can force transfers regardless

### Events
```solidity
event WhitelistUpdated(address indexed account, bool status, uint256 timestamp);
event BlacklistUpdated(address indexed account, bool status, uint256 timestamp);
```

---

## 3. Force Transfer

### Purpose
Allow admins to override transfers for compliance (court orders, sanctions, etc.).

### Implementation
```solidity
function forceTransfer(
    uint256 tokenId,
    address from,
    address to,
    string memory reason
) external onlyAdmin
```

### Usage
```solidity
// Force transfer with reason
goldAssetToken.forceTransfer(
    tokenId,
    currentOwner,
    newOwner,
    "Court order #2024-123"
);
```

### Features
- Only PLATFORM role can execute
- Bypasses whitelist/blacklist checks
- Requires explicit reason for audit trail
- Updates assetOwner mapping
- Emits OwnershipUpdated event

### Events
```solidity
event OwnershipUpdated(
    uint256 indexed tokenId,
    address indexed from,
    address indexed to,
    string reason,
    uint256 timestamp
);
```

---

## 4. GoldAccountLedger (IGAN System)

### Purpose
Create accounts with unique IGAN identifiers and track gold balances.

### Contract Functions

#### Create Account
```solidity
function createAccount(
    string memory memberGIC,
    address ownerAddress
) external onlyPlatform returns (string memory igan)
```

**Usage**:
```solidity
string memory igan = accountLedger.createAccount(
    "MEMBER-UAE-001",
    userWalletAddress
);
// Returns: "IGAN-1000"
```

#### Update Balance
```solidity
function updateBalance(
    string memory igan,
    int256 delta,
    string memory reason,
    uint256 tokenId
) external onlyAuthorized
```

**Usage**:
```solidity
// Increase balance (mint)
accountLedger.updateBalance("IGAN-1000", 1, "mint", tokenId);

// Decrease balance (burn)
accountLedger.updateBalance("IGAN-1000", -1, "burn", tokenId);
```

#### Query Functions
```solidity
// Get balance
uint256 balance = accountLedger.getAccountBalance("IGAN-1000");

// Get accounts by member
string[] memory accounts = accountLedger.getAccountsByMember("MEMBER-UAE-001");

// Get accounts by address
string[] memory accounts = accountLedger.getAccountsByAddress(userAddress);

// Get full account details
Account memory account = accountLedger.getAccountDetails("IGAN-1000");
```

### Account Structure
```solidity
struct Account {
    string igan;           // Unique identifier
    string memberGIC;      // Linked member
    address ownerAddress;  // Wallet address
    uint256 balance;       // Gold token count
    uint256 createdAt;     // Creation timestamp
    bool active;           // Account status
}
```

### Events
```solidity
event AccountCreated(
    string indexed igan,
    string indexed memberGIC,
    address indexed ownerAddress,
    uint256 timestamp
);

event BalanceUpdated(
    string indexed igan,
    int256 delta,
    uint256 newBalance,
    string reason,
    uint256 tokenId,
    uint256 timestamp
);
```

---

## 5. Enhanced Burn Function

### Purpose
Integrate burn operations with account ledger for balance tracking.

### Implementation
```solidity
function burn(
    uint256 tokenId,
    string memory accountId,  // ← NEW: IGAN required
    string memory burnReason
) external onlyOwnerOrCustodian(tokenId)
```

### Usage
```solidity
// Burn with account update
goldAssetToken.burn(
    tokenId,
    "IGAN-1000",  // ← Account to deduct from
    "Physical delivery completed"
);
```

### What Happens
1. Validates asset not already burned
2. Updates account balance: `balance -= 1`
3. Sets asset status to BURNED
4. Burns ERC-1155 token
5. Emits AssetBurned event

### Access Control
- Asset owner can burn
- CUSTODIAN role can burn
- PLATFORM role can burn

---

## 🔄 Integration Flow Examples

### Complete Minting Flow
```solidity
// 1. Create account (if not exists)
string memory igan = accountLedger.createAccount("MEMBER-001", refinerAddress);

// 2. Mint NFT with warrant
uint256 tokenId = goldAssetToken.mint(
    refinerAddress,
    "SN123456",
    "Refiner A",
    1000000,
    9999,
    GoldProductType.BAR,
    certHash,
    "GIFTCHZZ",
    true,
    "WARRANT-2024-001"
);

// 3. Update balance (optional - can be done automatically)
accountLedger.updateBalance(igan, 1, "mint", tokenId);
```

### Complete Transfer Flow
```solidity
// 1. Whitelist both parties
goldAssetToken.addToWhitelist(seller);
goldAssetToken.addToWhitelist(buyer);

// 2. Transfer NFT (standard ERC-1155)
goldAssetToken.safeTransferFrom(seller, buyer, tokenId, 1, "");

// 3. Update balances
accountLedger.updateBalance(sellerIGAN, -1, "transfer", tokenId);
accountLedger.updateBalance(buyerIGAN, 1, "transfer", tokenId);
```

### Complete Burn Flow
```solidity
// 1. Burn NFT (automatically updates balance)
goldAssetToken.burn(tokenId, "IGAN-1000", "Physical delivery");

// Balance is automatically decremented in GoldAccountLedger
```

### Compliance Force Transfer
```solidity
// 1. Admin force transfer (bypasses whitelist)
goldAssetToken.forceTransfer(
    tokenId,
    violatorAddress,
    custodianAddress,
    "Sanctions compliance"
);

// 2. Update balances
accountLedger.updateBalance(violatorIGAN, -1, "forced", tokenId);
accountLedger.updateBalance(custodianIGAN, 1, "forced", tokenId);
```

---

## 🔐 Access Control Summary

| Function | Required Role | Contract |
|----------|--------------|----------|
| createAccount | PLATFORM | GoldAccountLedger |
| updateBalance | PLATFORM or CUSTODIAN | GoldAccountLedger |
| mint | REFINER | GoldAssetToken |
| burn | Owner or CUSTODIAN | GoldAssetToken |
| forceTransfer | PLATFORM | GoldAssetToken |
| addToWhitelist | PLATFORM | GoldAssetToken |
| addToBlacklist | PLATFORM | GoldAssetToken |

---

## 📊 Event Monitoring

### Key Events to Index

**Warrant Tracking**:
```solidity
WarrantLinked(warrantId, tokenId, owner, timestamp)
```

**Compliance Actions**:
```solidity
OwnershipUpdated(tokenId, from, to, reason, timestamp)
WhitelistUpdated(account, status, timestamp)
BlacklistUpdated(account, status, timestamp)
```

**Account Management**:
```solidity
AccountCreated(igan, memberGIC, ownerAddress, timestamp)
BalanceUpdated(igan, delta, newBalance, reason, tokenId, timestamp)
```

---

## ⚠️ Important Notes

### Constructor Changes
**GoldAssetToken now requires 2 parameters**:
```solidity
// OLD
new GoldAssetToken(memberRegistryAddress)

// NEW
new GoldAssetToken(memberRegistryAddress, accountLedgerAddress)
```

### Mint Function Signature Changed
**Added warrantId parameter**:
```solidity
// OLD
mint(to, serial, refiner, weight, fineness, type, cert, gic, certified)

// NEW
mint(to, serial, refiner, weight, fineness, type, cert, gic, certified, warrantId)
```

### Burn Function Signature Changed
**Added accountId parameter**:
```solidity
// OLD
burn(tokenId, reason)

// NEW
burn(tokenId, accountId, reason)
```

---

## 🧪 Testing

All new features have comprehensive test coverage:

- ✅ Warrant duplicate prevention
- ✅ Whitelist/blacklist enforcement
- ✅ Force transfer bypass
- ✅ Account creation
- ✅ Balance updates
- ✅ Enhanced burn with ledger integration

Run tests:
```bash
forge test --summary
```

---

## 📝 Migration Guide

If you have existing code, update:

1. **Deployment script**: Add GoldAccountLedger deployment
2. **Mint calls**: Add warrantId parameter
3. **Burn calls**: Add accountId parameter
4. **Constructor**: Pass accountLedger address to GoldAssetToken

See `script/Deploy.s.sol` for reference implementation.
