// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MemberRegistry is Ownable {
    
    // Role constants
    uint256 constant ROLE_REFINER = 1 << 0;
    uint256 constant ROLE_TRADER = 1 << 1;
    uint256 constant ROLE_CUSTODIAN = 1 << 2;
    uint256 constant ROLE_VAULT_OP = 1 << 3;
    uint256 constant ROLE_LSP = 1 << 4;
    uint256 constant ROLE_AUDITOR = 1 << 5;
    uint256 constant ROLE_PLATFORM = 1 << 6;
    uint256 constant ROLE_GOVERNANCE = 1 << 7;

    // Enums
    enum MemberType {
        INDIVIDUAL,
        COMPANY,
        INSTITUTION
    }

    enum MemberStatus {
        PENDING,
        ACTIVE,
        SUSPENDED,
        TERMINATED
    }

    enum UserStatus {
        ACTIVE,
        INACTIVE,
        SUSPENDED
    }

    // Structs
    struct Member {
        string memberGIC;
        string entityName;
        string country;
        MemberType memberType;
        MemberStatus status;
        uint256 createdAt;
        uint256 updatedAt;
        bytes32 memberHash;
        uint256 roles;
    }

    struct User {
        string userId;
        bytes32 userHash;
        string linkedMemberGIC;
        UserStatus status;
        uint256 createdAt;
        address[] adminAddresses;
    }

    // State variables
    mapping(string => Member) public members;
    mapping(string => User) public users;
    mapping(address => string) public addressToMemberGIC;
    mapping(address => string) public addressToUserId;
    
    string[] public memberList;
    string[] public userList;

    // Events
    event MemberRegistered(
        string indexed memberGIC,
        MemberType memberType,
        address indexed registeredBy,
        uint256 timestamp
    );

    event MemberApproved(
        string indexed memberGIC,
        address indexed approvedBy,
        uint256 timestamp
    );

    event MemberSuspended(
        string indexed memberGIC,
        string reason,
        address indexed suspendedBy,
        uint256 timestamp
    );

    event UserRegistered(
        string indexed userId,
        bytes32 userHash,
        address indexed registeredBy,
        uint256 timestamp
    );

    event UserLinkedToMember(
        string indexed userId,
        string indexed memberGIC,
        address indexed linkedBy,
        uint256 timestamp
    );

    event RoleAssigned(
        string indexed memberGIC,
        uint256 role,
        address indexed assignedBy,
        uint256 timestamp
    );

    event RoleRevoked(
        string indexed memberGIC,
        uint256 role,
        address indexed revokedBy,
        uint256 timestamp
    );

    // Constructor
    constructor() Ownable(msg.sender) {
        // Set deployer as platform admin
        addressToMemberGIC[msg.sender] = "PLATFORM";
    }

    // Query Functions (declared early for use in modifiers)
    /**
     * @dev Check if member has role
     */
    function isMemberInRole(address member, uint256 role) 
        public view returns (bool) {
        string memory memberGIC = addressToMemberGIC[member];
        
        if (bytes(memberGIC).length == 0) {
            return false;
        }

        // Bootstrap: PLATFORM and GOVERNANCE are special bootstrap members
        if (keccak256(abi.encodePacked(memberGIC)) == keccak256(abi.encodePacked("PLATFORM"))) {
            return (ROLE_PLATFORM & role) != 0;
        }
        if (keccak256(abi.encodePacked(memberGIC)) == keccak256(abi.encodePacked("GOVERNANCE"))) {
            return (ROLE_GOVERNANCE & role) != 0;
        }

        Member memory m = members[memberGIC];
        
        if (m.status != MemberStatus.ACTIVE) {
            return false;
        }

        return (m.roles & role) != 0;
    }

    // Modifiers
    modifier onlyGovernance() {
        require(isMemberInRole(msg.sender, ROLE_GOVERNANCE), "Not authorized: GOVERNANCE role required");
        _;
    }

    modifier onlyPlatformAdmin() {
        require(isMemberInRole(msg.sender, ROLE_PLATFORM), "Not authorized: PLATFORM role required");
        _;
    }

    modifier memberExists(string memory memberGIC) {
        require(members[memberGIC].createdAt != 0, "Member does not exist");
        _;
    }

    modifier userExists(string memory userId) {
        require(users[userId].createdAt != 0, "User does not exist");
        _;
    }

    // Member Management Functions

    /**
     * @dev Register new member
     */
    function registerMember(
        string memory memberGIC,
        string memory entityName,
        string memory country,
        MemberType memberType,
        bytes32 memberHash
    ) external onlyPlatformAdmin returns (bool) {
        require(members[memberGIC].createdAt == 0, "Member already exists");
        require(bytes(memberGIC).length > 0, "Invalid member GIC");

        Member memory newMember = Member({
            memberGIC: memberGIC,
            entityName: entityName,
            country: country,
            memberType: memberType,
            status: MemberStatus.PENDING,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            memberHash: memberHash,
            roles: 0
        });

        members[memberGIC] = newMember;
        memberList.push(memberGIC);

        emit MemberRegistered(memberGIC, memberType, msg.sender, block.timestamp);
        return true;
    }

    /**
     * @dev Approve pending member
     */
    function approveMember(string memory memberGIC) 
        external onlyGovernance memberExists(memberGIC) returns (bool) {
        require(members[memberGIC].status == MemberStatus.PENDING, "Member not pending");

        members[memberGIC].status = MemberStatus.ACTIVE;
        members[memberGIC].updatedAt = block.timestamp;

        emit MemberApproved(memberGIC, msg.sender, block.timestamp);
        return true;
    }

    /**
     * @dev Suspend member
     */
    function suspendMember(string memory memberGIC, string memory reason) 
        external onlyPlatformAdmin memberExists(memberGIC) returns (bool) {
        require(members[memberGIC].status != MemberStatus.SUSPENDED, "Member already suspended");

        members[memberGIC].status = MemberStatus.SUSPENDED;
        members[memberGIC].updatedAt = block.timestamp;

        emit MemberSuspended(memberGIC, reason, msg.sender, block.timestamp);
        return true;
    }

    /**
     * @dev Terminate member
     */
    function terminateMember(string memory memberGIC) 
        external onlyGovernance memberExists(memberGIC) returns (bool) {
        members[memberGIC].status = MemberStatus.TERMINATED;
        members[memberGIC].updatedAt = block.timestamp;
        return true;
    }

    // Role Management Functions

    /**
     * @dev Assign role to member
     */
    function assignRole(string memory memberGIC, uint256 role) 
        external onlyGovernance memberExists(memberGIC) returns (bool) {
        require(members[memberGIC].status == MemberStatus.ACTIVE, "Member not active");
        
        members[memberGIC].roles |= role;
        members[memberGIC].updatedAt = block.timestamp;

        emit RoleAssigned(memberGIC, role, msg.sender, block.timestamp);
        return true;
    }

    /**
     * @dev Revoke role from member
     */
    function revokeRole(string memory memberGIC, uint256 role) 
        external onlyGovernance memberExists(memberGIC) returns (bool) {
        members[memberGIC].roles &= ~role;
        members[memberGIC].updatedAt = block.timestamp;

        emit RoleRevoked(memberGIC, role, msg.sender, block.timestamp);
        return true;
    }

    // User Management Functions

    /**
     * @dev Register new user
     */
    function registerUser(
        string memory userId,
        bytes32 userHash
    ) external onlyPlatformAdmin returns (bool) {
        require(users[userId].createdAt == 0, "User already exists");
        require(bytes(userId).length > 0, "Invalid user ID");

        address[] memory emptyAddresses = new address[](0);
        
        User memory newUser = User({
            userId: userId,
            userHash: userHash,
            linkedMemberGIC: "",
            status: UserStatus.ACTIVE,
            createdAt: block.timestamp,
            adminAddresses: emptyAddresses
        });

        users[userId] = newUser;
        userList.push(userId);
        addressToUserId[msg.sender] = userId;

        emit UserRegistered(userId, userHash, msg.sender, block.timestamp);
        return true;
    }

    /**
     * @dev Link user to member
     */
    function linkUserToMember(string memory userId, string memory memberGIC) 
        external onlyPlatformAdmin userExists(userId) memberExists(memberGIC) returns (bool) {
        require(bytes(users[userId].linkedMemberGIC).length == 0, "User already linked");

        users[userId].linkedMemberGIC = memberGIC;

        emit UserLinkedToMember(userId, memberGIC, msg.sender, block.timestamp);
        return true;
    }

    /**
     * @dev Add admin address to user
     */
    function addUserAdminAddress(string memory userId, address adminAddress) 
        external onlyPlatformAdmin userExists(userId) returns (bool) {
        require(adminAddress != address(0), "Invalid address");

        users[userId].adminAddresses.push(adminAddress);
        addressToUserId[adminAddress] = userId;
        return true;
    }

    /**
     * @dev Suspend user
     */
    function suspendUser(string memory userId) 
        external onlyPlatformAdmin userExists(userId) returns (bool) {
        users[userId].status = UserStatus.SUSPENDED;
        return true;
    }

    /**
     * @dev Activate user
     */
    function activateUser(string memory userId) 
        external onlyPlatformAdmin userExists(userId) returns (bool) {
        users[userId].status = UserStatus.ACTIVE;
        return true;
    }

    // Query Functions

    /**
     * @dev Get member status
     */
    function getMemberStatus(string memory memberGIC) 
        external view memberExists(memberGIC) returns (uint8) {
        return uint8(members[memberGIC].status);
    }

    /**
     * @dev Get member details
     */
    function getMemberDetails(string memory memberGIC) 
        external view memberExists(memberGIC) returns (Member memory) {
        return members[memberGIC];
    }

    /**
     * @dev Get user status
     */
    function getUserStatus(string memory userId) 
        external view userExists(userId) returns (uint8) {
        return uint8(users[userId].status);
    }

    /**
     * @dev Get user details
     */
    function getUserDetails(string memory userId) 
        external view userExists(userId) returns (User memory) {
        return users[userId];
    }

    /**
     * @dev Validate permission (member active + has role + user authorized)
     */
    function validatePermission(address member, uint256 role) 
        external view returns (bool) {
        string memory memberGIC = addressToMemberGIC[member];
        
        if (bytes(memberGIC).length == 0) {
            return false;
        }

        Member memory m = members[memberGIC];
        
        if (m.status != MemberStatus.ACTIVE) {
            return false;
        }

        return (m.roles & role) != 0;
    }

    /**
     * @dev Get all members count
     */
    function getMembersCount() external view returns (uint256) {
        return memberList.length;
    }

    /**
     * @dev Get all users count
     */
    function getUsersCount() external view returns (uint256) {
        return userList.length;
    }

    /**
     * @dev Link address to member (no member existence check for bootstrap)
     */
    function linkAddressToMember(address addr, string memory memberGIC) 
        external returns (bool) {
        // Allow owner to link addresses during bootstrap
        require(msg.sender == owner() || isMemberInRole(msg.sender, ROLE_PLATFORM), 
                "Not authorized: PLATFORM role required");
        addressToMemberGIC[addr] = memberGIC;
        return true;
    }
}
