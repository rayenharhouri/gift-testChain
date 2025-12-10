// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MemberRegistry.sol";

contract MemberRegistryTest is Test {
    MemberRegistry public registry;
    
    address governance = address(0x2);
    address refiner = address(0x3);
    address trader = address(0x4);

    uint256 constant ROLE_REFINER = 1 << 0;
    uint256 constant ROLE_TRADER = 1 << 1;
    uint256 constant ROLE_GOVERNANCE = 1 << 7;
    uint256 constant ROLE_PLATFORM = 1 << 6;

    function setUp() public {
        registry = new MemberRegistry();
        // Deployer (address(this)) is already PLATFORM in constructor
        registry.linkAddressToMember(governance, "GOVERNANCE");
    }

    function test_RegisterMember() public {
        bool success = registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        assertTrue(success);
        
        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(member.memberGIC, "GIFTCHZZ");
        assertEq(member.entityName, "Swiss Refinery");
        assertEq(member.country, "CH");
        assertEq(uint8(member.status), uint8(MemberRegistry.MemberStatus.PENDING));
    }

    function test_ApproveMember() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        vm.prank(governance);
        bool success = registry.approveMember("GIFTCHZZ");

        assertTrue(success);
        
        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(uint8(member.status), uint8(MemberRegistry.MemberStatus.ACTIVE));
    }

    function test_AssignRole() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        vm.prank(governance);
        registry.approveMember("GIFTCHZZ");

        vm.prank(governance);
        bool success = registry.assignRole("GIFTCHZZ", ROLE_REFINER);

        assertTrue(success);
        
        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(member.roles & ROLE_REFINER, ROLE_REFINER);
    }

    function test_IsMemberInRole() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        vm.prank(governance);
        registry.approveMember("GIFTCHZZ");

        vm.prank(governance);
        registry.assignRole("GIFTCHZZ", ROLE_REFINER);

        registry.linkAddressToMember(refiner, "GIFTCHZZ");

        bool hasRole = registry.isMemberInRole(refiner, ROLE_REFINER);
        assertTrue(hasRole);
    }

    function test_RevokeRole() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        vm.prank(governance);
        registry.approveMember("GIFTCHZZ");

        vm.prank(governance);
        registry.assignRole("GIFTCHZZ", ROLE_REFINER);

        vm.prank(governance);
        bool success = registry.revokeRole("GIFTCHZZ", ROLE_REFINER);

        assertTrue(success);
        
        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(member.roles & ROLE_REFINER, 0);
    }

    function test_SuspendMember() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        vm.prank(governance);
        registry.approveMember("GIFTCHZZ");

        bool success = registry.suspendMember("GIFTCHZZ", "Compliance violation");

        assertTrue(success);
        
        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(uint8(member.status), uint8(MemberRegistry.MemberStatus.SUSPENDED));
    }

    function test_TerminateMember() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        vm.prank(governance);
        registry.approveMember("GIFTCHZZ");

        vm.prank(governance);
        bool success = registry.terminateMember("GIFTCHZZ");

        assertTrue(success);
        
        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(uint8(member.status), uint8(MemberRegistry.MemberStatus.TERMINATED));
    }

    function test_RegisterUser() public {
        bool success = registry.registerUser(
            "USR-2025-00001",
            keccak256("user_hash")
        );

        assertTrue(success);
        
        MemberRegistry.User memory user = registry.getUserDetails("USR-2025-00001");
        assertEq(user.userId, "USR-2025-00001");
        assertEq(uint8(user.status), uint8(MemberRegistry.UserStatus.ACTIVE));
    }

    function test_LinkUserToMember() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        registry.registerUser(
            "USR-2025-00001",
            keccak256("user_hash")
        );

        bool success = registry.linkUserToMember("USR-2025-00001", "GIFTCHZZ");

        assertTrue(success);
        
        MemberRegistry.User memory user = registry.getUserDetails("USR-2025-00001");
        assertEq(user.linkedMemberGIC, "GIFTCHZZ");
    }

    function test_AddUserAdminAddress() public {
        registry.registerUser(
            "USR-2025-00001",
            keccak256("user_hash")
        );

        bool success = registry.addUserAdminAddress("USR-2025-00001", refiner);

        assertTrue(success);
        
        MemberRegistry.User memory user = registry.getUserDetails("USR-2025-00001");
        assertEq(user.adminAddresses[0], refiner);
    }

    function test_SuspendUser() public {
        registry.registerUser(
            "USR-2025-00001",
            keccak256("user_hash")
        );

        bool success = registry.suspendUser("USR-2025-00001");

        assertTrue(success);
        
        MemberRegistry.User memory user = registry.getUserDetails("USR-2025-00001");
        assertEq(uint8(user.status), uint8(MemberRegistry.UserStatus.SUSPENDED));
    }

    function test_ActivateUser() public {
        registry.registerUser(
            "USR-2025-00001",
            keccak256("user_hash")
        );

        registry.suspendUser("USR-2025-00001");

        bool success = registry.activateUser("USR-2025-00001");

        assertTrue(success);
        
        MemberRegistry.User memory user = registry.getUserDetails("USR-2025-00001");
        assertEq(uint8(user.status), uint8(MemberRegistry.UserStatus.ACTIVE));
    }

    function test_ValidatePermission() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        vm.prank(governance);
        registry.approveMember("GIFTCHZZ");

        vm.prank(governance);
        registry.assignRole("GIFTCHZZ", ROLE_REFINER);

        registry.linkAddressToMember(refiner, "GIFTCHZZ");

        bool valid = registry.validatePermission(refiner, ROLE_REFINER);
        assertTrue(valid);
    }

    function test_OnlyGovernanceCanApprove() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        vm.prank(trader);
        vm.expectRevert("Not authorized: GOVERNANCE role required");
        registry.approveMember("GIFTCHZZ");
    }

    function test_OnlyGovernanceCanAssignRole() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        vm.prank(governance);
        registry.approveMember("GIFTCHZZ");

        vm.prank(trader);
        vm.expectRevert("Not authorized: GOVERNANCE role required");
        registry.assignRole("GIFTCHZZ", ROLE_REFINER);
    }

    function test_GetMembersCount() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        registry.registerMember(
            "GIFTUSAA",
            "US Refinery",
            "US",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash2")
        );

        assertEq(registry.getMembersCount(), 2);
    }

    function test_GetUsersCount() public {
        registry.registerUser("USR-2025-00001", keccak256("user_hash1"));

        registry.registerUser("USR-2025-00002", keccak256("user_hash2"));

        assertEq(registry.getUsersCount(), 2);
    }

    function test_GetMemberDetails() public {
        registry.registerMember(
            "GIFTCHZZ",
            "Swiss Refinery",
            "CH",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash")
        );

        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(member.memberGIC, "GIFTCHZZ");
        assertEq(member.entityName, "Swiss Refinery");
        assertEq(member.country, "CH");
    }

    function test_GetUserDetails() public {
        registry.registerUser(
            "USR-2025-00001",
            keccak256("user_hash")
        );

        MemberRegistry.User memory user = registry.getUserDetails("USR-2025-00001");
        assertEq(user.userId, "USR-2025-00001");
        assertEq(uint8(user.status), uint8(MemberRegistry.UserStatus.ACTIVE));
    }
}
