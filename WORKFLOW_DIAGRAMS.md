# GIFT Blockchain - Workflow Diagrams

**Visual Representation of All Workflows**

---

## 1. Member Registration & Approval Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MEMBER REGISTRATION WORKFLOW                             │
└─────────────────────────────────────────────────────────────────────────────┘

Step 1: PLATFORM Admin Registers Member
┌──────────────────────────────────────────────────────────────┐
│ PLATFORM calls: registerMember()                             │
│ ├─ memberGIC: "GIFTCHZZ"                                    │
│ ├─ entityName: "Swiss Refinery"                             │
│ ├─ country: "CH"                                            │
│ ├─ memberType: COMPANY                                      │
│ └─ memberHash: keccak256(off-chain-data)                   │
└──────────────────────────────────────────────────────────────┘
                              ↓
        ✅ Member created with status = PENDING
        ✅ Event: MemberRegistered emitted
                              ↓
Step 2: GOVERNANCE Approves Member
┌──────────────────────────────────────────────────────────────┐
│ GOVERNANCE calls: approveMember("GIFTCHZZ")                 │
│ ├─ Check: Member exists                                     │
│ ├─ Check: Status is PENDING                                 │
│ └─ Update: Status = ACTIVE                                  │
└──────────────────────────────────────────────────────────────┘
                              ↓
        ✅ Member now ACTIVE
        ✅ Event: MemberApproved emitted
                              ↓
Step 3: GOVERNANCE Assigns Roles
┌──────────────────────────────────────────────────────────────┐
│ GOVERNANCE calls: assignRole("GIFTCHZZ", ROLE_REFINER)     │
│ ├─ Check: Member exists                                     │
│ ├─ Check: Member is ACTIVE                                  │
│ ├─ Operation: roles |= ROLE_REFINER                         │
│ └─ Result: Member now has REFINER role                      │
└──────────────────────────────────────────────────────────────┘
                              ↓
        ✅ Member can now mint gold assets
        ✅ Event: RoleAssigned emitted
```

---

## 2. Authorization Check Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    THREE-LEVEL AUTHORIZATION                                │
└─────────────────────────────────────────────────────────────────────────────┘

When REFINER calls: goldToken.mint()
                              │
                              ▼
        ┌─────────────────────────────────────┐
        │ Level 1: Address Linked?            │
        │ addressToMemberGIC[0x123...] = ?    │
        └─────────────────────────────────────┘
                    │                    │
            ✅ YES  │                    │  ❌ NO
                    ▼                    ▼
            Continue              REVERT
                    │
                    ▼
        ┌─────────────────────────────────────┐
        │ Level 2: Member ACTIVE?             │
        │ members[GIC].status == ACTIVE?      │
        └─────────────────────────────────────┘
                    │                    │
            ✅ YES  │                    │  ❌ NO
                    ▼                    ▼
            Continue              REVERT
                    │
                    ▼
        ┌─────────────────────────────────────┐
        │ Level 3: Has Role?                  │
        │ (roles & ROLE_REFINER) != 0?        │
        └─────────────────────────────────────┘
                    │                    │
            ✅ YES  │                    │  ❌ NO
                    ▼                    ▼
            PROCEED              REVERT
            MINT ASSET           "Not authorized"
```

---

## 3. Gold Asset Minting Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GOLD ASSET MINTING WORKFLOW                              │
└─────────────────────────────────────────────────────────────────────────────┘

REFINER calls: mint(
    to: 0x456...,
    serialNumber: "SN123456",
    refinerName: "Refiner A",
    weightGrams: 1000000,
    fineness: 9999,
    productType: BAR,
    certificateHash: 0xabc...,
    traceabilityGIC: "GIFTCHZZ",
    certified: true
)
                              │
                              ▼
        ┌─────────────────────────────────────┐
        │ Step 1: Authorization Check         │
        │ isMemberInRole(refiner, REFINER)?   │
        └─────────────────────────────────────┘
                    │
                    ▼ ✅ PASS
        ┌─────────────────────────────────────┐
        │ Step 2: Duplicate Prevention        │
        │ key = keccak256(SN + refiner)       │
        │ _registeredAssets[key] exists?      │
        └─────────────────────────────────────┘
                    │
                    ▼ ✅ NOT FOUND
        ┌─────────────────────────────────────┐
        │ Step 3: Mark as Registered          │
        │ _registeredAssets[key] = true       │
        └─────────────────────────────────────┘
                    │
                    ▼
        ┌─────────────────────────────────────┐
        │ Step 4: Calculate Fine Weight       │
        │ fineWeight = (1000000 * 9999) /     │
        │             10000 = 999900          │
        └─────────────────────────────────────┘
                    │
                    ▼
        ┌─────────────────────────────────────┐
        │ Step 5: Create GoldAsset Struct     │
        │ tokenId: "GIFT-ASSET-2025-0001"     │
        │ status: REGISTERED                  │
        │ mintedAt: block.timestamp           │
        └─────────────────────────────────────┘
                    │
                    ▼
        ┌─────────────────────────────────────┐
        │ Step 6: Mint ERC1155 Token          │
        │ _mint(to, tokenId, 1, "")           │
        └─────────────────────────────────────┘
                    │
                    ▼
        ┌─────────────────────────────────────┐
        │ Step 7: Emit Event                  │
        │ AssetMinted(tokenId, SN, refiner,   │
        │            weight, fineness, owner) │
        └─────────────────────────────────────┘
                    │
                    ▼
        ✅ MINT SUCCESSFUL
        Return tokenId = 1
```

---

## 4. Asset Status Update Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ASSET STATUS UPDATE WORKFLOW                             │
└─────────────────────────────────────────────────────────────────────────────┘

CUSTODIAN calls: updateStatus(
    tokenId: 1,
    newStatus: IN_VAULT,
    reason: "Stored in vault"
)
                              │
                              ▼
        ┌─────────────────────────────────────┐
        │ Step 1: Authorization Check         │
        │ Owner or CUSTODIAN?                 │
        └─────────────────────────────────────┘
                    │
                    ▼ ✅ PASS
        ┌─────────────────────────────────────┐
        │ Step 2: Verify Asset Exists         │
        │ assets[1].mintedAt != 0?            │
        └─────────────────────────────────────┘
                    │
                    ▼ ✅ EXISTS
        ┌─────────────────────────────────────┐
        │ Step 3: Check Not Burned            │
        │ status != BURNED?                   │
        └─────────────────────────────────────┘
                    │
                    ▼ ✅ NOT BURNED
        ┌─────────────────────────────────────┐
        │ Step 4: Store Previous Status       │
        │ previousStatus = REGISTERED         │
        └─────────────────────────────────────┘
                    │
                    ▼
        ┌─────────────────────────────────────┐
        │ Step 5: Update Status               │
        │ assets[1].status = IN_VAULT         │
        └─────────────────────────────────────┘
                    │
                    ▼
        ┌─────────────────────────────────────┐
        │ Step 6: Emit Event                  │
        │ AssetStatusChanged(tokenId,         │
        │    REGISTERED, IN_VAULT, reason)    │
        └─────────────────────────────────────┘
                    │
                    ▼
        ✅ STATUS UPDATED
```

---

## 5. User Registration & Linking Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    USER REGISTRATION & LINKING WORKFLOW                     │
└─────────────────────────────────────────────────────────────────────────────┘

Step 1: PLATFORM Registers User
┌──────────────────────────────────────────────────────────────┐
│ PLATFORM calls: registerUser(                                │
│     userId: "USR-2025-00001",                               │
│     userHash: keccak256(identity)                           │
│ )                                                            │
└──────────────────────────────────────────────────────────────┘
                              ▼
        ✅ User created with status = ACTIVE
        ✅ Event: UserRegistered emitted
                              ▼
Step 2: PLATFORM Links User to Member
┌──────────────────────────────────────────────────────────────┐
│ PLATFORM calls: linkUserToMember(                            │
│     userId: "USR-2025-00001",                               │
│     memberGIC: "GIFTCHZZ"                                   │
│ )                                                            │
│ ├─ Check: User exists                                       │
│ ├─ Check: Member exists                                     │
│ ├─ Check: User not already linked                           │
│ └─ Update: linkedMemberGIC = "GIFTCHZZ"                    │
└──────────────────────────────────────────────────────────────┘
                              ▼
        ✅ User linked to member
        ✅ User inherits member's permissions
        ✅ Event: UserLinkedToMember emitted
                              ▼
Step 3: PLATFORM Adds Admin Address
┌──────────────────────────────────────────────────────────────┐
│ PLATFORM calls: addUserAdminAddress(                         │
│     userId: "USR-2025-00001",                               │
│     adminAddress: 0x789...                                  │
│ )                                                            │
│ ├─ Check: User exists                                       │
│ ├─ Check: Address not zero                                  │
│ ├─ Push: Address to adminAddresses[]                        │
│ └─ Map: addressToUserId[0x789...] = "USR-2025-00001"       │
└──────────────────────────────────────────────────────────────┘
                              ▼
        ✅ Address linked to user
        ✅ Address can now perform operations
```

---

## 6. Role Assignment & Revocation Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ROLE ASSIGNMENT & REVOCATION WORKFLOW                    │
└─────────────────────────────────────────────────────────────────────────────┘

ASSIGN ROLE:
┌──────────────────────────────────────────────────────────────┐
│ GOVERNANCE calls: assignRole("GIFTCHZZ", ROLE_REFINER)     │
│ ├─ Check: Member exists                                     │
│ ├─ Check: Member is ACTIVE                                  │
│ ├─ Operation: roles |= ROLE_REFINER                         │
│ │  Before: 0b00000000 (no roles)                            │
│ │  After:  0b00000001 (REFINER)                             │
│ └─ Emit: RoleAssigned event                                 │
└──────────────────────────────────────────────────────────────┘

ASSIGN ANOTHER ROLE:
┌──────────────────────────────────────────────────────────────┐
│ GOVERNANCE calls: assignRole("GIFTCHZZ", ROLE_TRADER)      │
│ ├─ Check: Member exists                                     │
│ ├─ Check: Member is ACTIVE                                  │
│ ├─ Operation: roles |= ROLE_TRADER                          │
│ │  Before: 0b00000001 (REFINER)                             │
│ │  After:  0b00000011 (REFINER + TRADER)                    │
│ └─ Emit: RoleAssigned event                                 │
└──────────────────────────────────────────────────────────────┘

REVOKE ROLE:
┌──────────────────────────────────────────────────────────────┐
│ GOVERNANCE calls: revokeRole("GIFTCHZZ", ROLE_REFINER)     │
│ ├─ Check: Member exists                                     │
│ ├─ Operation: roles &= ~ROLE_REFINER                        │
│ │  Before: 0b00000011 (REFINER + TRADER)                    │
│ │  After:  0b00000010 (TRADER only)                         │
│ └─ Emit: RoleRevoked event                                  │
└──────────────────────────────────────────────────────────────┘
```

---

## 7. Duplicate Prevention Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DUPLICATE PREVENTION WORKFLOW                            │
└─────────────────────────────────────────────────────────────────────────────┘

First Mint:
┌──────────────────────────────────────────────────────────────┐
│ REFINER calls: mint(                                         │
│     serialNumber: "SN123456",                               │
│     refinerName: "Refiner A",                               │
│     ...                                                      │
│ )                                                            │
│ ├─ Create key: keccak256("SN123456" + "Refiner A")         │
│ ├─ Check: _registeredAssets[key] == false                  │
│ ├─ Mark: _registeredAssets[key] = true                     │
│ └─ Mint: Success ✅                                         │
└──────────────────────────────────────────────────────────────┘

Second Mint (Same Serial + Refiner):
┌──────────────────────────────────────────────────────────────┐
│ REFINER calls: mint(                                         │
│     serialNumber: "SN123456",                               │
│     refinerName: "Refiner A",                               │
│     ...                                                      │
│ )                                                            │
│ ├─ Create key: keccak256("SN123456" + "Refiner A")         │
│ ├─ Check: _registeredAssets[key] == true                   │
│ └─ REVERT: "Asset already registered" ❌                    │
└──────────────────────────────────────────────────────────────┘

Different Refiner (Same Serial):
┌──────────────────────────────────────────────────────────────┐
│ REFINER calls: mint(                                         │
│     serialNumber: "SN123456",                               │
│     refinerName: "Refiner B",  ← Different refiner          │
│     ...                                                      │
│ )                                                            │
│ ├─ Create key: keccak256("SN123456" + "Refiner B")         │
│ ├─ Check: _registeredAssets[key] == false                  │
│ ├─ Mark: _registeredAssets[key] = true                     │
│ └─ Mint: Success ✅                                         │
└──────────────────────────────────────────────────────────────┘
```

---

## 8. Member Lifecycle State Machine

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MEMBER LIFECYCLE STATE MACHINE                           │
└─────────────────────────────────────────────────────────────────────────────┘

                    registerMember()
                          │
                          ▼
                    ┌──────────────┐
                    │   PENDING    │  ← Initial state
                    │              │     Cannot perform operations
                    └──────────────┘
                          │
                          │ approveMember() [GOVERNANCE]
                          ▼
                    ┌──────────────┐
                    │   ACTIVE     │  ← Can perform operations
                    │              │     Can be assigned roles
                    └──────────────┘
                      ▲         │
                      │         │ suspendMember() [PLATFORM]
                      │         ▼
                      │    ┌──────────────┐
                      │    │  SUSPENDED   │  ← Cannot perform operations
                      │    │              │     Roles still assigned
                      │    └──────────────┘
                      │         │
                      │         │ (cannot reactivate)
                      │         ▼
                      │    ┌──────────────┐
                      │    │ TERMINATED   │  ← Final state
                      │    │              │     Permanent
                      │    └──────────────┘
                      │
                      └─ (can be reactivated from SUSPENDED)
```

---

## 9. Asset Lifecycle State Machine

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ASSET LIFECYCLE STATE MACHINE                            │
└─────────────────────────────────────────────────────────────────────────────┘

                    mint()
                      │
                      ▼
            ┌──────────────────┐
            │   REGISTERED     │  ← Initial state
            │                  │     Asset created
            └──────────────────┘
                      │
                      │ updateStatus()
                      ▼
            ┌──────────────────┐
            │   IN_VAULT       │  ← Stored in vault
            │                  │     Stationary
            └──────────────────┘
                      │
                      ├─ updateStatus()
                      │      │
                      │      ▼
                      │  ┌──────────────────┐
                      │  │   IN_TRANSIT     │  ← Being transported
                      │  │                  │     Locked
                      │  └──────────────────┘
                      │      │
                      │      │ updateStatus()
                      │      ▼
                      │  ┌──────────────────┐
                      │  │   IN_VAULT       │  ← Back to vault
                      │  │                  │
                      │  └──────────────────┘
                      │
                      ├─ updateStatus()
                      │      │
                      │      ▼
                      │  ┌──────────────────┐
                      │  │   PLEDGED        │  ← Locked as collateral
                      │  │                  │     Cannot transfer
                      │  └──────────────────┘
                      │
                      ▼
            ┌──────────────────┐
            │   BURNED         │  ← Final state
            │                  │     Irreversible
            └──────────────────┘
```

---

## 10. Authorization Check Bitwise Operations

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BITWISE ROLE OPERATIONS                                  │
└─────────────────────────────────────────────────────────────────────────────┘

ROLE CONSTANTS:
┌──────────────────────────────────────────────────────────────┐
│ ROLE_REFINER    = 1 << 0 = 0b00000001 = 1                  │
│ ROLE_TRADER     = 1 << 1 = 0b00000010 = 2                  │
│ ROLE_CUSTODIAN  = 1 << 2 = 0b00000100 = 4                  │
│ ROLE_VAULT_OP   = 1 << 3 = 0b00001000 = 8                  │
│ ROLE_LSP        = 1 << 4 = 0b00010000 = 16                 │
│ ROLE_AUDITOR    = 1 << 5 = 0b00100000 = 32                 │
│ ROLE_PLATFORM   = 1 << 6 = 0b01000000 = 64                 │
│ ROLE_GOVERNANCE = 1 << 7 = 0b10000000 = 128                │
└──────────────────────────────────────────────────────────────┘

ASSIGN ROLE (Bitwise OR):
┌──────────────────────────────────────────────────────────────┐
│ roles |= ROLE_REFINER                                        │
│                                                              │
│ Before: 0b00000000 (no roles)                               │
│ OR with: 0b00000001 (ROLE_REFINER)                          │
│ Result: 0b00000001 (has REFINER)                            │
└──────────────────────────────────────────────────────────────┘

ASSIGN ANOTHER ROLE:
┌──────────────────────────────────────────────────────────────┐
│ roles |= ROLE_TRADER                                         │
│                                                              │
│ Before: 0b00000001 (REFINER)                                │
│ OR with: 0b00000010 (ROLE_TRADER)                           │
│ Result: 0b00000011 (REFINER + TRADER)                       │
└──────────────────────────────────────────────────────────────┘

CHECK ROLE (Bitwise AND):
┌──────────────────────────────────────────────────────────────┐
│ (roles & ROLE_REFINER) != 0                                  │
│                                                              │
│ roles: 0b00000011 (REFINER + TRADER)                        │
│ AND with: 0b00000001 (ROLE_REFINER)                         │
│ Result: 0b00000001 (non-zero = true)                        │
│ ✅ Has REFINER role                                         │
└──────────────────────────────────────────────────────────────┘

REVOKE ROLE (Bitwise AND NOT):
┌──────────────────────────────────────────────────────────────┐
│ roles &= ~ROLE_REFINER                                       │
│                                                              │
│ Before: 0b00000011 (REFINER + TRADER)                       │
│ AND with: ~0b00000001 = 0b11111110                          │
│ Result: 0b00000010 (TRADER only)                            │
└──────────────────────────────────────────────────────────────┘
```

---

## 11. Fine Weight Calculation Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FINE WEIGHT CALCULATION                                  │
└─────────────────────────────────────────────────────────────────────────────┘

Input Parameters:
┌──────────────────────────────────────────────────────────────┐
│ weightGrams: 1000000 (100 grams, scaled by 10^4)            │
│ fineness: 9999 (99.99% pure)                                │
└──────────────────────────────────────────────────────────────┘

Calculation:
┌──────────────────────────────────────────────────────────────┐
│ fineWeightGrams = (weightGrams * fineness) / 10000          │
│                 = (1000000 * 9999) / 10000                  │
│                 = 9999000000 / 10000                         │
│                 = 999900                                     │
└──────────────────────────────────────────────────────────────┘

Result:
┌──────────────────────────────────────────────────────────────┐
│ Gross Weight: 100 grams                                      │
│ Purity: 99.99%                                               │
│ Fine Weight: 99.99 grams                                     │
│ Loss: 0.01 grams (impurities)                               │
└──────────────────────────────────────────────────────────────┘
```

---

**All Workflows Documented & Tested ✅**
