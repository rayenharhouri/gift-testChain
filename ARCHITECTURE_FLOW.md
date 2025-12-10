# GIFT Architecture Flow - MemberRegistry Relationship

## Current Status

### ✅ Completed: GoldAssetToken (ERC1155 NFT)
- Minting gold assets as NFTs
- Status management (REGISTERED → IN_VAULT → PLEDGED → BURNED)
- Duplicate prevention
- Certificate verification
- All tests passing

### ⏳ Next: MemberRegistry (Identity Layer)
- Master registry of members, users, and roles
- Central authorization hub

---

## Direct Relationship: MemberRegistry ↔ GoldAssetToken

### How They Connect

```
MemberRegistry (Layer 1: Identity)
        ↓
        └─→ Validates Authorization
                ↓
        GoldAssetToken (Layer 2: Asset)
                ↓
        Uses roles to control:
        • Who can MINT (ROLE_REFINER)
        • Who can UPDATE status (ROLE_CUSTODIAN)
        • Who can BURN (ROLE_PLATFORM)
```

### Current Implementation

**GoldAssetToken already depends on MemberRegistry:**

```solidity
interface IMemberRegistry {
    function isMemberInRole(address member, uint256 role) external view returns (bool);
}

contract GoldAssetToken is ERC1155, Ownable {
    IMemberRegistry public memberRegistry;
    
    modifier onlyRefiner() {
        require(memberRegistry.isMemberInRole(msg.sender, ROLE_REFINER), 
                "Not authorized");
        _;
    }
}
```

### What Happens Without MemberRegistry

**Current Test Setup** uses MockMemberRegistry:
```solidity
contract MockMemberRegistry {
    mapping(address => uint256) public roles;
    
    function isMemberInRole(address member, uint256 role) 
        external view returns (bool) {
        return (roles[member] & role) != 0;
    }
}
```

This is a **temporary mock** for testing. In production, you need the **real MemberRegistry**.

---

## Why MemberRegistry is Critical

### 1. Access Control
- Defines who can mint gold assets
- Defines who can update status
- Defines who can burn assets
- Defines who can manage vaults

### 2. Member Management
- Register refineries (ROLE_REFINER)
- Register custodians (ROLE_CUSTODIAN)
- Register traders (ROLE_TRADER)
- Register vault operators (ROLE_VAULT_OP)
- Register auditors (ROLE_AUDITOR)

### 3. Role Hierarchy
```
ROLE_REFINER (1 << 0)      → Can mint NFTs
ROLE_TRADER (1 << 1)       → Can create transactions
ROLE_CUSTODIAN (1 << 2)    → Can manage custody
ROLE_VAULT_OP (1 << 3)     → Can manage vaults
ROLE_LSP (1 << 4)          → Logistics provider
ROLE_AUDITOR (1 << 5)      → Can audit
ROLE_PLATFORM (1 << 6)     → Admin functions
ROLE_GOVERNANCE (1 << 7)   → Governance council
```

---

## Dependency Chain

```
Layer 1: Identity
├── MemberRegistry ← MUST CREATE FIRST
│   └── Stores: Members, Users, Roles
│
Layer 2: Asset & Vault
├── GoldAssetToken (ERC1155) ← DEPENDS ON MemberRegistry
│   └── Uses: ROLE_REFINER, ROLE_CUSTODIAN, ROLE_PLATFORM
├── VaultRegistry ← DEPENDS ON MemberRegistry
│   └── Uses: ROLE_VAULT_OP, ROLE_AUDITOR
│
Layer 3: Account & Ledger
├── GoldAccountLedger ← DEPENDS ON MemberRegistry, VaultRegistry, GoldAssetToken
│   └── Uses: All roles
│
Layer 4: Transaction & Logistics
├── TransactionOrderBook ← DEPENDS ON MemberRegistry, GoldAccountLedger
├── TransactionEventLogger ← DEPENDS ON MemberRegistry
│
Layer 5: Documents & Dispute
└── DocumentRegistry ← DEPENDS ON MemberRegistry
```

---

## What MemberRegistry Does

### Data Structures
```solidity
struct Member {
    string memberGIC;           // Global ID (e.g., "GIFTCHZZ")
    string entityName;          // Organization name
    string country;             // ISO country code
    MemberType memberType;      // INDIVIDUAL, COMPANY, INSTITUTION
    MemberStatus status;        // PENDING, ACTIVE, SUSPENDED, TERMINATED
    uint256 createdAt;
    uint256 updatedAt;
    bytes32 memberHash;         // Hash of off-chain data
}

struct User {
    string userId;              // User ID
    bytes32 userHash;           // Hash of identity (no PII on-chain)
    string linkedMemberGIC;     // Which member this user belongs to
    UserStatus status;          // ACTIVE, INACTIVE, SUSPENDED
    address[] adminAddresses;   // Wallet addresses authorized
}
```

### Key Functions
```solidity
registerMember()        // Register new member (refinery, vault, etc.)
approveMember()         // Approve pending member
assignRole()            // Give member a role (REFINER, CUSTODIAN, etc.)
isMemberInRole()        // Check if member has role (used by all contracts)
registerUser()          // Register individual user
linkUserToMember()      // Link user to member organization
```

---

## Deployment Order

```
1. MemberRegistry ← Deploy FIRST (no dependencies)
   ↓
2. GoldAssetToken ← Deploy SECOND (depends on MemberRegistry)
   ↓
3. VaultRegistry ← Deploy THIRD (depends on MemberRegistry)
   ↓
4. GoldAccountLedger ← Deploy FOURTH (depends on 1, 2, 3)
   ↓
5. TransactionOrderBook ← Deploy FIFTH (depends on 1, 2, 4)
   ↓
6. TransactionEventLogger ← Deploy SIXTH
   ↓
7. DocumentRegistry ← Deploy SEVENTH
```

---

## Real-World Flow Example

### Scenario: Refinery wants to mint gold

```
1. Refinery registers with MemberRegistry
   → memberGIC = "GIFTCHZZ"
   → memberType = COMPANY
   → status = PENDING

2. Governance approves refinery
   → status = ACTIVE

3. Governance assigns role
   → assignRole("GIFTCHZZ", ROLE_REFINER)

4. Refinery calls GoldAssetToken.mint()
   → GoldAssetToken checks: isMemberInRole(refinery_address, ROLE_REFINER)
   → MemberRegistry returns: true
   → Mint succeeds ✅

5. If unauthorized address tries to mint
   → GoldAssetToken checks: isMemberInRole(hacker_address, ROLE_REFINER)
   → MemberRegistry returns: false
   → Mint fails ❌
```

---

## Summary

| Aspect | Details |
|--------|---------|
| **Relationship** | MemberRegistry is the authorization hub for GoldAssetToken |
| **Direct Dependency** | Yes - GoldAssetToken calls MemberRegistry for every protected operation |
| **Current Status** | GoldAssetToken works with MockMemberRegistry for testing |
| **Production Need** | Real MemberRegistry must be deployed before GoldAssetToken |
| **Deployment Order** | MemberRegistry first, then GoldAssetToken |
| **Role of MemberRegistry** | Manages members, users, and role assignments |
| **Role of GoldAssetToken** | Uses MemberRegistry to enforce access control on NFT operations |

---

## Next Steps

1. **Create MemberRegistry contract** - Implements member/user/role management
2. **Deploy MemberRegistry** - On GIFT blockchain
3. **Update GoldAssetToken** - Point to real MemberRegistry (not mock)
4. **Register test members** - Refineries, custodians, traders
5. **Assign roles** - Give members appropriate permissions
6. **Test end-to-end** - Verify authorization flow works

Ready to create MemberRegistry?
