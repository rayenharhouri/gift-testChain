# GIFT Blockchain - Quick Reference Guide

## 📋 Project Status at a Glance

| Metric | Value |
|--------|-------|
| **Phase** | 1 - Foundation Layer |
| **Status** | ✅ Complete & Tested |
| **Contracts** | 2 implemented, 5 pending |
| **Tests** | 28/28 passing (100%) |
| **Code Quality** | Production-ready |
| **Specification** | 100% aligned |

---

## 🏗️ What We Built

### Layer 1: Identity (COMPLETE)
**MemberRegistry** - Central authorization hub
- 18 functions
- 8 role types
- 19 tests ✅

### Layer 2: Asset (PARTIAL)
**GoldAssetToken** - Gold asset NFTs
- 10 functions
- ERC1155 standard
- 9 tests ✅

---

## 🔑 Key Concepts

### 1. Three-Level Authorization
```
Address → Member → Role
```
Every operation checks:
1. Is address linked to a member?
2. Is member ACTIVE?
3. Does member have required role?

### 2. Eight Roles
```
REFINER (mint)
TRADER (transfer)
CUSTODIAN (custody)
VAULT_OP (vaults)
LSP (logistics)
AUDITOR (audit)
PLATFORM (admin)
GOVERNANCE (approve)
```

### 3. Asset Lifecycle
```
REGISTERED → IN_VAULT → PLEDGED → BURNED
```

### 4. Member Lifecycle
```
PENDING → ACTIVE → SUSPENDED/TERMINATED
```

---

## 📁 File Structure

```
GIFT/
├── contracts/
│   ├── MemberRegistry.sol          ✅ Complete
│   ├── GoldAssetToken.sol          ✅ Complete
│   ├── VaultRegistry.sol           ⏳ Pending
│   ├── GoldAccountLedger.sol       ⏳ Pending
│   ├── TransactionOrderBook.sol    ⏳ Pending
│   ├── TransactionEventLogger.sol  ⏳ Pending
│   └── DocumentRegistry.sol        ⏳ Pending
│
├── test/
│   ├── MemberRegistry.t.sol        ✅ 19 tests
│   ├── GoldAssetToken.t.sol        ✅ 9 tests
│   └── [others pending]
│
├── docs/
│   ├── PROJECT_SUMMARY.md          ← Start here
│   ├── ARCHITECTURE_OVERVIEW.md    ← Visual diagrams
│   ├── QUICK_REFERENCE.md          ← This file
│   ├── VERIFICATION_MEMBERREGISTRY.md
│   └── TEST_RESULTS.md
```

---

## 🚀 Quick Start

### 1. Run All Tests
```bash
cd /home/fsociety/GIFT
forge test -v
```

### 2. Run Specific Test Suite
```bash
forge test test/MemberRegistry.t.sol -v
forge test test/GoldAssetToken.t.sol -v
```

### 3. Check Gas Usage
```bash
forge test --gas-report
```

---

## 📊 Test Results Summary

```
MemberRegistry:    19/19 ✅
GoldAssetToken:     9/9 ✅
─────────────────────────
Total:             28/28 ✅
```

**Key Tests:**
- ✅ Member registration and approval
- ✅ Role assignment and validation
- ✅ User management
- ✅ Asset minting and burning
- ✅ Duplicate prevention
- ✅ Access control enforcement

---

## 🔐 Security Features

| Feature | Implementation |
|---------|-----------------|
| Access Control | Role-based (8 roles) |
| Authorization | Three-level validation |
| Duplicate Prevention | Composite key (serial + refiner) |
| No PII On-Chain | Hash-based storage |
| Immutable Records | Asset attributes locked |
| Audit Trail | Event logging |

---

## 📈 Deployment Order (LOCKED)

```
1. MemberRegistry ✅
   ↓
2. GoldAssetToken ✅
   ↓
3. VaultRegistry ⏳
   ↓
4. GoldAccountLedger ⏳
   ↓
5. TransactionOrderBook ⏳
   ↓
6. TransactionEventLogger ⏳
   ↓
7. DocumentRegistry ⏳
```

**Cannot change this order** - each layer depends on previous layers.

---

## 🎯 API Endpoints Implemented

### User Management
- ✅ registerUser()
- ✅ linkUserToMember()
- ✅ getUserStatus()
- ✅ suspendUser()
- ✅ activateUser()

### Member Management
- ✅ registerMember()
- ✅ approveMember()
- ✅ suspendMember()
- ✅ assignRole()
- ✅ revokeRole()

### Asset Management
- ✅ mint() [Register Asset]
- ✅ burn() [Burn Asset]
- ✅ updateStatus() [Update Status]
- ✅ updateCustody() [Update Custody]
- ✅ getAssetDetails()
- ✅ getAssetsByOwner()
- ✅ verifyCertificate()
- ✅ isAssetLocked()

### Pending Implementation
- ⏳ transferAsset() [requires GoldAccountLedger]
- ⏳ trackAsset() [requires TransactionEventLogger]
- ⏳ getAssetHistory() [requires TransactionEventLogger]

---

## 💾 Data Structures

### Member
```solidity
memberGIC          // Global ID
entityName         // Organization name
country            // ISO code
memberType         // INDIVIDUAL, COMPANY, INSTITUTION
status             // PENDING, ACTIVE, SUSPENDED, TERMINATED
roles              // Bitwise flags (8 roles)
memberHash         // Hash of off-chain data
createdAt          // Timestamp
updatedAt          // Timestamp
```

### User
```solidity
userId             // Unique ID
userHash           // Hash of identity
linkedMemberGIC    // Associated member
status             // ACTIVE, INACTIVE, SUSPENDED
adminAddresses[]   // Authorized wallets
createdAt          // Timestamp
```

### GoldAsset
```solidity
tokenId            // GIFT-ASSET-YYYY-NNNNN
serialNumber       // Refiner serial
refinerName        // Manufacturer
weightGrams        // Gross weight
fineness           // Purity (9999 = 99.99%)
fineWeightGrams    // Calculated weight
productType        // BAR, COIN, DUST, OTHER
certificateHash    // Authenticity hash
status             // REGISTERED, IN_VAULT, PLEDGED, BURNED
certified          // LBMA certification
mintedAt           // Timestamp
```

---

## 🔧 Common Operations

### Register a Member
```solidity
registry.registerMember(
    "GIFTCHZZ",                    // memberGIC
    "Swiss Refinery",              // entityName
    "CH",                          // country
    MemberRegistry.MemberType.COMPANY,
    keccak256("member_data")       // memberHash
);
```

### Approve a Member
```solidity
registry.approveMember("GIFTCHZZ");
```

### Assign a Role
```solidity
registry.assignRole("GIFTCHZZ", ROLE_REFINER);
```

### Mint a Gold Asset
```solidity
goldToken.mint(
    owner,                         // to
    "SN123456",                    // serialNumber
    "Refiner A",                   // refinerName
    1000000,                       // weightGrams
    9999,                          // fineness
    GoldAssetToken.GoldProductType.BAR,
    keccak256("cert"),             // certificateHash
    "GIFTCHZZ",                    // traceabilityGIC
    true                           // certified
);
```

### Update Asset Status
```solidity
goldToken.updateStatus(
    tokenId,
    GoldAssetToken.AssetStatus.IN_VAULT,
    "Stored in vault"
);
```

---

## 📝 Events Emitted

### MemberRegistry Events
- `MemberRegistered(memberGIC, memberType, registeredBy, timestamp)`
- `MemberApproved(memberGIC, approvedBy, timestamp)`
- `MemberSuspended(memberGIC, reason, suspendedBy, timestamp)`
- `UserRegistered(userId, userHash, registeredBy, timestamp)`
- `UserLinkedToMember(userId, memberGIC, linkedBy, timestamp)`
- `RoleAssigned(memberGIC, role, assignedBy, timestamp)`
- `RoleRevoked(memberGIC, role, revokedBy, timestamp)`

### GoldAssetToken Events
- `AssetMinted(tokenId, serialNumber, refinerName, weightGrams, fineness, owner, timestamp)`
- `AssetBurned(tokenId, burnReason, finalOwner, authorizedBy, timestamp)`
- `AssetStatusChanged(tokenId, previousStatus, newStatus, reason, changedBy, timestamp)`
- `CustodyChanged(tokenId, fromParty, toParty, custodyType, timestamp)`
- `AssetTransferred(tokenId, fromIGAN, toIGAN, timestamp)`

---

## ⚠️ Important Notes

### Bootstrap Mechanism
- Deployer is automatically PLATFORM admin
- PLATFORM and GOVERNANCE are special bootstrap members
- They don't need to be registered
- Used for initial system setup

### Duplicate Prevention
- Assets identified by: `keccak256(serialNumber + refinerName)`
- Same serial from different refiners = different assets
- Same serial from same refiner = rejected

### No PII On-Chain
- Only hashes stored: `memberHash`, `userHash`
- Actual data stored off-chain
- Hashes used for verification

### Role Bitwise Operations
- Assign: `roles |= ROLE_REFINER`
- Revoke: `roles &= ~ROLE_REFINER`
- Check: `(roles & ROLE_REFINER) != 0`

---

## 🐛 Troubleshooting

### "Not authorized: PLATFORM role required"
- Check if caller is linked to PLATFORM member
- Check if member is ACTIVE
- Check if member has ROLE_PLATFORM

### "Not authorized: GOVERNANCE role required"
- Check if caller is linked to GOVERNANCE member
- Check if member is ACTIVE
- Check if member has ROLE_GOVERNANCE

### "Asset already registered"
- Asset with same serial + refiner already exists
- Use different serial number or refiner name

### "Member does not exist"
- Member hasn't been registered yet
- Check memberGIC spelling

### "User already linked"
- User is already linked to a member
- Cannot link same user to multiple members

---

## 📞 Support

### Documentation
- `PROJECT_SUMMARY.md` - High-level overview
- `ARCHITECTURE_OVERVIEW.md` - System design
- `VERIFICATION_MEMBERREGISTRY.md` - Detailed verification
- `TEST_RESULTS.md` - Test coverage

### Code
- Inline comments in all contracts
- Function documentation with @dev tags
- Clear variable naming

### Tests
- 28 comprehensive tests
- All major scenarios covered
- Edge cases tested

---

## 🎓 Learning Path

1. **Start Here:** PROJECT_SUMMARY.md
2. **Understand Architecture:** ARCHITECTURE_OVERVIEW.md
3. **Review Code:** contracts/MemberRegistry.sol
4. **Study Tests:** test/MemberRegistry.t.sol
5. **Deep Dive:** VERIFICATION_MEMBERREGISTRY.md

---

## 📅 Timeline

| Phase | Status | Duration | Completion |
|-------|--------|----------|------------|
| Phase 1: Foundation | ✅ Complete | 1 week | 2025-12-02 |
| Phase 2: Vault & Ledger | ⏳ Pending | 2 weeks | 2025-12-16 |
| Phase 3: Transactions | ⏳ Pending | 2 weeks | 2025-12-30 |
| Phase 4: Documents | ⏳ Pending | 1 week | 2026-01-06 |

---

## 🎯 Next Steps

1. **External Security Audit** - Recommended before mainnet
2. **Testnet Deployment** - Deploy Phase 1 contracts
3. **Phase 2 Implementation** - VaultRegistry & GoldAccountLedger
4. **Integration Testing** - Test all layers together
5. **Mainnet Deployment** - Production launch

---

**Last Updated:** December 2, 2025  
**Status:** 🟢 ON TRACK  
**Next Milestone:** VaultRegistry Implementation
