# GIFT Blockchain - Technical Breakdown

**What We Built - Detailed Implementation**

---

## 📋 Contract 1: MemberRegistry

### Purpose
Central authorization hub for all GIFT operations. Manages members, users, and role assignments.

---

## 🔧 Functions Implemented (18 Total)

### Member Management Functions

#### 1. registerMember()
```solidity
function registerMember(
    string memory memberGIC,
    string memory entityName,
    string memory country,
    MemberType memberType,
    bytes32 memberHash
) external onlyPlatformAdmin returns (bool)
```
**What it does:**
- Creates new member organization
- Sets initial status to PENDING
- Stores member hash (no PII on-chain)
- Prevents duplicate members

**Access:** PLATFORM admin only

**Workflow:**
1. Check member doesn't already exist
2. Validate memberGIC is not empty
3. Create Member struct with PENDING status
4. Store in members mapping
5. Add to memberList array
6. Emit MemberRegistered event

---

#### 2. approveMember()
```solidity
function approveMember(string memory memberGIC) 
    external onlyGovernance memberExists(memberGIC) returns (bool)
```
**What it does:**
- Changes member status from PENDING to ACTIVE
- Allows member to perform operations

**Access:** GOVERNANCE only

**Workflow:**
1. Check member exists
2. Verify member is PENDING
3. Change status to ACTIVE
4. Update timestamp
5. Emit MemberApproved event

---

#### 3. suspendMember()
```solidity
function suspendMember(string memory memberGIC, string memory reason) 
    external onlyPlatformAdmin memberExists(memberGIC) returns (bool)
```
**What it does:**
- Suspends active member
- Prevents all operations
- Logs reason for suspension

**Access:** PLATFORM admin only

**Workflow:**
1. Check member exists
2. Verify not already suspended
3. Change status to SUSPENDED
4. Update timestamp
5. Emit MemberSuspended event with reason

---

#### 4. terminateMember()
```solidity
function terminateMember(string memory memberGIC) 
    external onlyGovernance memberExists(memberGIC) returns (bool)
```
**What it does:**
- Permanently terminates member
- Final state (cannot be reactivated)

**Access:** GOVERNANCE only

**Workflow:**
1. Check member exists
2. Change status to TERMINATED
3. Update timestamp
4. Return true

---

### Role Management Functions

#### 5. assignRole()
```solidity
function assignRole(string memory memberGIC, uint256 role) 
    external onlyGovernance memberExists(memberGIC) returns (bool)
```
**What it does:**
- Assigns role to active member
- Uses bitwise OR operation
- Member can have multiple roles

**Access:** GOVERNANCE only

**Workflow:**
1. Check member exists
2. Verify member is ACTIVE
3. Use bitwise OR: `roles |= role`
4. Update timestamp
5. Emit RoleAssigned event

**Example:**
```
Member has: ROLE_REFINER (0b00000001)
Assign: ROLE_TRADER (0b00000010)
Result: 0b00000011 (both roles)
```

---

#### 6. revokeRole()
```solidity
function revokeRole(string memory memberGIC, uint256 role) 
    external onlyGovernance memberExists(memberGIC) returns (bool)
```
**What it does:**
- Removes role from member
- Uses bitwise AND NOT operation
- Other roles unaffected

**Access:** GOVERNANCE only

**Workflow:**
1. Check member exists
2. Use bitwise AND NOT: `roles &= ~role`
3. Update timestamp
4. Emit RoleRevoked event

**Example:**
```
Member has: 0b00000011 (REFINER + TRADER)
Revoke: ROLE_TRADER (0b00000010)
Result: 0b00000001 (only REFINER)
```

---

### User Management Functions

#### 7. registerUser()
```solidity
function registerUser(
    string memory userId,
    bytes32 userHash
) external onlyPlatformAdmin returns (bool)
```
**What it does:**
- Creates new user account
- Stores hash of identity (no PII)
- Sets initial status to ACTIVE

**Access:** PLATFORM admin only

**Workflow:**
1. Check user doesn't exist
2. Validate userId not empty
3. Create User struct with ACTIVE status
4. Initialize empty adminAddresses array
5. Store in users mapping
6. Add to userList array
7. Emit UserRegistered event

---

#### 8. linkUserToMember()
```solidity
function linkUserToMember(string memory userId, string memory memberGIC) 
    external onlyPlatformAdmin userExists(userId) memberExists(memberGIC) returns (bool)
```
**What it does:**
- Associates user with member organization
- User inherits member's permissions
- One-time operation (cannot relink)

**Access:** PLATFORM admin only

**Workflow:**
1. Check user exists
2. Check member exists
3. Verify user not already linked
4. Set linkedMemberGIC
5. Emit UserLinkedToMember event

---

#### 9. addUserAdminAddress()
```solidity
function addUserAdminAddress(string memory userId, address adminAddress) 
    external onlyPlatformAdmin userExists(userId) returns (bool)
```
**What it does:**
- Adds wallet address to user
- User can have multiple addresses
- Maps address to userId

**Access:** PLATFORM admin only

**Workflow:**
1. Check user exists
2. Validate address not zero
3. Push address to adminAddresses array
4. Map address to userId
5. Return true

---

#### 10. suspendUser()
```solidity
function suspendUser(string memory userId) 
    external onlyPlatformAdmin userExists(userId) returns (bool)
```
**What it does:**
- Suspends user account
- Prevents access

**Access:** PLATFORM admin only

**Workflow:**
1. Check user exists
2. Change status to SUSPENDED
3. Return true

---

#### 11. activateUser()
```solidity
function activateUser(string memory userId) 
    external onlyPlatformAdmin userExists(userId) returns (bool)
```
**What it does:**
- Reactivates suspended user
- Restores access

**Access:** PLATFORM admin only

**Workflow:**
1. Check user exists
2. Change status to ACTIVE
3. Return true

---

### Authorization & Query Functions

#### 12. isMemberInRole()
```solidity
function isMemberInRole(address member, uint256 role) 
    public view returns (bool)
```
**What it does:**
- Core authorization function
- Three-level validation
- Used by all other contracts

**Access:** Public (view only)

**Workflow:**
1. Get memberGIC from address
2. If no member linked → return false
3. Check for bootstrap members (PLATFORM, GOVERNANCE)
4. Get member from storage
5. Check member is ACTIVE
6. Check role using bitwise AND: `(roles & role) != 0`
7. Return result

**Three-Level Validation:**
```
Level 1: Address linked to member?
Level 2: Member is ACTIVE?
Level 3: Member has role?
```

---

#### 13. validatePermission()
```solidity
function validatePermission(address member, uint256 role) 
    external view returns (bool)
```
**What it does:**
- Combined permission check
- Same as isMemberInRole

**Access:** Public (view only)

---

#### 14. getMemberStatus()
```solidity
function getMemberStatus(string memory memberGIC) 
    external view memberExists(memberGIC) returns (uint8)
```
**What it does:**
- Returns member status as uint8
- 0=PENDING, 1=ACTIVE, 2=SUSPENDED, 3=TERMINATED

**Access:** Public (view only)

---

#### 15. getMemberDetails()
```solidity
function getMemberDetails(string memory memberGIC) 
    external view memberExists(memberGIC) returns (Member memory)
```
**What it does:**
- Returns complete member struct
- All member information

**Access:** Public (view only)

---

#### 16. getUserStatus()
```solidity
function getUserStatus(string memory userId) 
    external view userExists(userId) returns (uint8)
```
**What it does:**
- Returns user status as uint8
- 0=ACTIVE, 1=INACTIVE, 2=SUSPENDED

**Access:** Public (view only)

---

#### 17. getUserDetails()
```solidity
function getUserDetails(string memory userId) 
    external view userExists(userId) returns (User memory)
```
**What it does:**
- Returns complete user struct
- All user information

**Access:** Public (view only)

---

#### 18. getMembersCount() & getUsersCount()
```solidity
function getMembersCount() external view returns (uint256)
function getUsersCount() external view returns (uint256)
```
**What it does:**
- Returns total count of members/users
- Used for enumeration

**Access:** Public (view only)

---

## 🎭 Role Constants (8 Total)

```solidity
uint256 constant ROLE_REFINER = 1 << 0;      // 0b00000001 = 1
uint256 constant ROLE_TRADER = 1 << 1;       // 0b00000010 = 2
uint256 constant ROLE_CUSTODIAN = 1 << 2;    // 0b00000100 = 4
uint256 constant ROLE_VAULT_OP = 1 << 3;     // 0b00001000 = 8
uint256 constant ROLE_LSP = 1 << 4;          // 0b00010000 = 16
uint256 constant ROLE_AUDITOR = 1 << 5;      // 0b00100000 = 32
uint256 constant ROLE_PLATFORM = 1 << 6;     // 0b01000000 = 64
uint256 constant ROLE_GOVERNANCE = 1 << 7;   // 0b10000000 = 128
```

**Why Bitwise?**
- Efficient storage (1 uint256 = 8 roles)
- Fast checking: `(roles & ROLE_REFINER) != 0`
- Easy assignment: `roles |= ROLE_REFINER`
- Easy revocation: `roles &= ~ROLE_REFINER`

---

## 📡 Events (7 Total)

### 1. MemberRegistered
```solidity
event MemberRegistered(
    string indexed memberGIC,
    MemberType memberType,
    address indexed registeredBy,
    uint256 timestamp
)
```
**Emitted when:** New member registered
**Indexed fields:** memberGIC, registeredBy (for filtering)

---

### 2. MemberApproved
```solidity
event MemberApproved(
    string indexed memberGIC,
    address indexed approvedBy,
    uint256 timestamp
)
```
**Emitted when:** Member approved to ACTIVE

---

### 3. MemberSuspended
```solidity
event MemberSuspended(
    string indexed memberGIC,
    string reason,
    address indexed suspendedBy,
    uint256 timestamp
)
```
**Emitted when:** Member suspended
**Includes:** Reason for suspension

---

### 4. UserRegistered
```solidity
event UserRegistered(
    string indexed userId,
    bytes32 userHash,
    address indexed registeredBy,
    uint256 timestamp
)
```
**Emitted when:** New user registered

---

### 5. UserLinkedToMember
```solidity
event UserLinkedToMember(
    string indexed userId,
    string indexed memberGIC,
    address indexed linkedBy,
    uint256 timestamp
)
```
**Emitted when:** User linked to member

---

### 6. RoleAssigned
```solidity
event RoleAssigned(
    string indexed memberGIC,
    uint256 role,
    address indexed assignedBy,
    uint256 timestamp
)
```
**Emitted when:** Role assigned to member

---

### 7. RoleRevoked
```solidity
event RoleRevoked(
    string indexed memberGIC,
    uint256 role,
    address indexed revokedBy,
    uint256 timestamp
)
```
**Emitted when:** Role revoked from member

---

## 🔐 Modifiers (4 Total)

### 1. onlyGovernance()
```solidity
modifier onlyGovernance() {
    require(isMemberInRole(msg.sender, ROLE_GOVERNANCE), 
            "Not authorized: GOVERNANCE role required");
    _;
}
```
**Used by:** approveMember, assignRole, revokeRole, terminateMember

---

### 2. onlyPlatformAdmin()
```solidity
modifier onlyPlatformAdmin() {
    require(isMemberInRole(msg.sender, ROLE_PLATFORM), 
            "Not authorized: PLATFORM role required");
    _;
}
```
**Used by:** registerMember, registerUser, linkUserToMember, suspendMember, etc.

---

### 3. memberExists()
```solidity
modifier memberExists(string memory memberGIC) {
    require(members[memberGIC].createdAt != 0, "Member does not exist");
    _;
}
```
**Used by:** All member-related functions

---

### 4. userExists()
```solidity
modifier userExists(string memory userId) {
    require(users[userId].createdAt != 0, "User does not exist");
    _;
}
```
**Used by:** All user-related functions

---

## 📊 Data Structures

### Member Struct
```solidity
struct Member {
    string memberGIC;           // Global ID (e.g., "GIFTCHZZ")
    string entityName;          // Organization name
    string country;             // ISO country code
    MemberType memberType;      // INDIVIDUAL, COMPANY, INSTITUTION
    MemberStatus status;        // PENDING, ACTIVE, SUSPENDED, TERMINATED
    uint256 createdAt;          // Block timestamp
    uint256 updatedAt;          // Last update timestamp
    bytes32 memberHash;         // Hash of off-chain data
    uint256 roles;              // Bitwise role flags
}
```

### User Struct
```solidity
struct User {
    string userId;              // Unique user ID
    bytes32 userHash;           // Hash of identity
    string linkedMemberGIC;     // Associated member
    UserStatus status;          // ACTIVE, INACTIVE, SUSPENDED
    uint256 createdAt;          // Block timestamp
    address[] adminAddresses;   // Authorized wallets
}
```

---

## 🧪 Test Coverage (19 Tests)

### Member Management Tests (4)
1. ✅ test_RegisterMember - Register new member
2. ✅ test_ApproveMember - Approve to ACTIVE
3. ✅ test_SuspendMember - Suspend member
4. ✅ test_TerminateMember - Terminate member

### Role Management Tests (3)
5. ✅ test_AssignRole - Assign role to member
6. ✅ test_RevokeRole - Revoke role from member
7. ✅ test_IsMemberInRole - Check member has role

### User Management Tests (5)
8. ✅ test_RegisterUser - Register new user
9. ✅ test_LinkUserToMember - Link user to member
10. ✅ test_AddUserAdminAddress - Add wallet to user
11. ✅ test_SuspendUser - Suspend user
12. ✅ test_ActivateUser - Activate user

### Query Tests (4)
13. ✅ test_GetMemberDetails - Get member info
14. ✅ test_GetUserDetails - Get user info
15. ✅ test_GetMembersCount - Count members
16. ✅ test_GetUsersCount - Count users

### Access Control Tests (2)
17. ✅ test_OnlyGovernanceCanApprove - Verify governance-only
18. ✅ test_OnlyGovernanceCanAssignRole - Verify governance-only

### Permission Tests (1)
19. ✅ test_ValidatePermission - Combined permission check

**Test Pass Rate:** 19/19 (100%)

---

## 📋 Contract 2: GoldAssetToken

### Purpose
ERC1155 NFT representation of physical gold assets with immutable attributes and status tracking.

---

## 🔧 Functions Implemented (10 Total)

### Core Functions

#### 1. mint()
```solidity
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
) external onlyRefiner returns (uint256)
```
**What it does:**
- Creates new gold asset NFT
- Prevents duplicates (serial + refiner)
- Calculates fine weight
- Stores immutable attributes

**Access:** REFINER role only

**Workflow:**
1. Check caller has ROLE_REFINER
2. Create composite key: `keccak256(serialNumber + refinerName)`
3. Verify asset not already registered
4. Mark asset as registered
5. Calculate fine weight: `(weightGrams * fineness) / 10000`
6. Create GoldAsset struct
7. Mint ERC1155 token (amount = 1)
8. Emit AssetMinted event
9. Return tokenId

**Duplicate Prevention:**
```solidity
bytes32 key = keccak256(abi.encodePacked(serialNumber, refinerName));
require(!_registeredAssets[key], "Asset already registered");
_registeredAssets[key] = true;
```

---

#### 2. burn()
```solidity
function burn(uint256 tokenId, string memory burnReason) 
    external
```
**What it does:**
- Permanently retires asset
- Irreversible operation
- Logs burn reason

**Access:** Owner or PLATFORM admin

**Workflow:**
1. Check caller is owner or PLATFORM
2. Verify asset not already burned
3. Set status to BURNED
4. Burn ERC1155 token
5. Emit AssetBurned event

---

#### 3. updateStatus()
```solidity
function updateStatus(
    uint256 tokenId,
    AssetStatus newStatus,
    string memory reason
) external onlyOwnerOrCustodian(tokenId)
```
**What it does:**
- Changes asset status
- Logs reason for change
- Prevents updating burned assets

**Access:** Owner or CUSTODIAN role

**Workflow:**
1. Check caller is owner or CUSTODIAN
2. Verify asset not burned
3. Store previous status
4. Update to new status
5. Emit AssetStatusChanged event

**Valid Statuses:**
- REGISTERED (newly created)
- IN_VAULT (stored in vault)
- IN_TRANSIT (being transported)
- PLEDGED (locked as collateral)
- BURNED (permanently retired)
- MISSING (location unknown)
- STOLEN (confirmed theft)

---

#### 4. updateCustody()
```solidity
function updateCustody(
    uint256 tokenId,
    address toParty,
    string memory custodyType
) external onlyOwnerOrCustodian(tokenId)
```
**What it does:**
- Updates custody information
- Doesn't change ownership
- Tracks who has physical custody

**Access:** Owner or CUSTODIAN role

**Workflow:**
1. Check caller is owner or CUSTODIAN
2. Get current owner
3. Emit CustodyChanged event

---

### Query Functions

#### 5. getAssetDetails()
```solidity
function getAssetDetails(uint256 tokenId) 
    external view returns (GoldAsset memory)
```
**What it does:**
- Returns complete asset information
- All immutable attributes

**Access:** Public (view only)

---

#### 6. getAssetsByOwner()
```solidity
function getAssetsByOwner(address owner) 
    external view returns (uint256[] memory)
```
**What it does:**
- Returns all assets owned by address
- Excludes burned assets

**Access:** Public (view only)

**Workflow:**
1. Loop through all assets
2. Count assets owned by address (not burned)
3. Create result array
4. Populate with matching token IDs
5. Return array

---

#### 7. isAssetLocked()
```solidity
function isAssetLocked(uint256 tokenId) 
    external view returns (bool)
```
**What it does:**
- Checks if asset is in locked status
- Returns true for PLEDGED or IN_TRANSIT

**Access:** Public (view only)

**Workflow:**
```solidity
AssetStatus status = assets[tokenId].status;
return status == AssetStatus.PLEDGED || status == AssetStatus.IN_TRANSIT;
```

---

#### 8. verifyCertificate()
```solidity
function verifyCertificate(uint256 tokenId, bytes32 certificateHash) 
    external view returns (bool)
```
**What it does:**
- Verifies certificate authenticity
- Compares provided hash with stored hash

**Access:** Public (view only)

**Workflow:**
```solidity
return assets[tokenId].certificateHash == certificateHash;
```

---

#### 9. uri()
```solidity
function uri(uint256 tokenId) 
    public view override returns (string memory)
```
**What it does:**
- Returns metadata URI for token
- ERC1155 standard override

**Access:** Public (view only)

---

#### 10. setMemberRegistry()
```solidity
function setMemberRegistry(address _memberRegistry) 
    external onlyOwner
```
**What it does:**
- Updates MemberRegistry address
- Admin function

**Access:** Owner only

---

## 🎭 Role Constants (3 Used)

```solidity
uint256 constant ROLE_REFINER = 1 << 0;      // Can mint
uint256 constant ROLE_CUSTODIAN = 1 << 2;    // Can update status
uint256 constant ROLE_PLATFORM = 1 << 6;     // Can burn
```

---

## 📡 Events (5 Total)

### 1. AssetMinted
```solidity
event AssetMinted(
    uint256 indexed tokenId,
    string serialNumber,
    string refinerName,
    uint256 weightGrams,
    uint256 fineness,
    address indexed owner,
    uint256 timestamp
)
```

### 2. AssetBurned
```solidity
event AssetBurned(
    uint256 indexed tokenId,
    string burnReason,
    address indexed finalOwner,
    address indexed authorizedBy,
    uint256 timestamp
)
```

### 3. AssetStatusChanged
```solidity
event AssetStatusChanged(
    uint256 indexed tokenId,
    AssetStatus previousStatus,
    AssetStatus newStatus,
    string reason,
    address indexed changedBy,
    uint256 timestamp
)
```

### 4. CustodyChanged
```solidity
event CustodyChanged(
    uint256 indexed tokenId,
    address indexed fromParty,
    address indexed toParty,
    string custodyType,
    uint256 timestamp
)
```

### 5. AssetTransferred
```solidity
event AssetTransferred(
    uint256 indexed tokenId,
    address indexed fromIGAN,
    address indexed toIGAN,
    uint256 timestamp
)
```

---

## 🔐 Modifiers (3 Total)

### 1. onlyRefiner()
```solidity
modifier onlyRefiner() {
    require(memberRegistry.isMemberInRole(msg.sender, ROLE_REFINER), 
            "Not authorized: REFINER role required");
    _;
}
```

### 2. onlyOwnerOrCustodian()
```solidity
modifier onlyOwnerOrCustodian(uint256 tokenId) {
    require(
        assetOwner[tokenId] == msg.sender || 
        memberRegistry.isMemberInRole(msg.sender, ROLE_CUSTODIAN),
        "Not authorized: Owner or CUSTODIAN role required"
    );
    _;
}
```

### 3. onlyAdmin()
```solidity
modifier onlyAdmin() {
    require(memberRegistry.isMemberInRole(msg.sender, ROLE_PLATFORM), 
            "Not authorized: PLATFORM role required");
    _;
}
```

---

## 📊 Data Structures

### GoldAsset Struct
```solidity
struct GoldAsset {
    string tokenId;             // GIFT-ASSET-YYYY-NNNNN
    string serialNumber;        // Refiner serial
    string refinerName;         // Manufacturer
    uint256 weightGrams;        // Gross weight (scaled by 10^4)
    uint256 fineness;           // Purity (9999 = 99.99%)
    uint256 fineWeightGrams;    // Calculated: weight × fineness / 10000
    GoldProductType productType; // BAR, COIN, DUST, OTHER
    bytes32 certificateHash;    // Authenticity hash
    string traceabilityGIC;     // Introducing member
    AssetStatus status;         // Current status
    uint256 mintedAt;           // Block timestamp
    bool certified;             // LBMA certification
}
```

---

## 🧪 Test Coverage (9 Tests)

### Asset Minting Tests (2)
1. ✅ test_MintGoldAsset - Mint new asset
2. ✅ test_OnlyRefinerCanMint - Verify REFINER-only access

### Duplicate Prevention Tests (1)
3. ✅ test_DuplicatePreventionFails - Prevent duplicates

### Asset Status Tests (2)
4. ✅ test_UpdateStatus - Update asset status
5. ✅ test_IsAssetLocked - Check if locked

### Asset Burning Tests (1)
6. ✅ test_BurnAsset - Burn asset

### Query Tests (2)
7. ✅ test_GetAssetsByOwner - Get owner's assets
8. ✅ test_VerifyCertificate - Verify certificate

### Calculation Tests (1)
9. ✅ test_FineWeightCalculation - Verify fine weight

**Test Pass Rate:** 9/9 (100%)

---

## 🔄 Workflow: Asset Registration to Burn

```
1. REFINER calls mint()
   ├─ Check: isMemberInRole(refiner, ROLE_REFINER)
   ├─ Prevent: Duplicate (serial + refiner)
   ├─ Create: ERC1155 NFT
   └─ Emit: AssetMinted

2. CUSTODIAN calls updateStatus()
   ├─ Check: isMemberInRole(custodian, ROLE_CUSTODIAN)
   ├─ Update: Status = IN_VAULT
   └─ Emit: AssetStatusChanged

3. TRADER calls transferAsset() [Future - GoldAccountLedger]
   ├─ Check: isMemberInRole(trader, ROLE_TRADER)
   ├─ Validate: Asset not locked
   ├─ Update: Ownership
   └─ Emit: AssetTransferred

4. OWNER calls burn()
   ├─ Check: Owner or PLATFORM
   ├─ Update: Status = BURNED
   ├─ Burn: ERC1155 token
   └─ Emit: AssetBurned
```

---

## 📈 Test Coverage Summary

| Component | Tests | Pass Rate |
|-----------|-------|-----------|
| MemberRegistry | 19 | 100% ✅ |
| GoldAssetToken | 9 | 100% ✅ |
| **Total** | **28** | **100% ✅** |

---

## 🔐 Security Features

### MemberRegistry
- ✅ Three-level authorization (address → member → role)
- ✅ Role-based access control (8 roles)
- ✅ Member lifecycle management
- ✅ Bootstrap mechanism
- ✅ No PII on-chain (hash-based)

### GoldAssetToken
- ✅ Duplicate prevention (serial + refiner)
- ✅ Immutable asset attributes
- ✅ Role-based access control
- ✅ Status management
- ✅ Certificate verification
- ✅ ERC1155 standard compliance

---

## 📊 Gas Efficiency

**Bitwise Operations:**
- Assign role: `roles |= ROLE_REFINER` (1 operation)
- Revoke role: `roles &= ~ROLE_REFINER` (1 operation)
- Check role: `(roles & ROLE_REFINER) != 0` (1 operation)

**Storage:**
- 8 roles in 1 uint256 (vs 8 separate booleans)
- Saves ~7 storage slots per member

---

**Status:** ✅ COMPLETE & TESTED
