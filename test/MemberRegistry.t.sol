// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MemberRegistry.sol";

contract MemberRegistryTest is Test {
    MemberRegistry public registry;
    
    address admin = address(0x1);
    address governance = address(0x2);
    address refiner = address(0x3);
    address trader = address(0x4);

    uint256 constant ROLE_REFINER = 1 << 0;
    uint256 constant ROLE_MINTER = 1 << 1;
    uint256 constant ROLE_GOVERNANCE = 1 << 7;
    uint256 constant ROLE_PLATFORM = 1 << 6;

    function setUp() public {
        registry = new MemberRegistry();
        
        vm.prank(address(this));
        registry.linkAddressToMember(admin, "PLATFORM");
        registry.linkAddressToMember(governance, "GOVERNANCE");
    }

    function test_RegisterMember() public {
        vm.prank(admin);
        bool success = registry.registerMember(
            "GIFTCHZZ",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash"),
            refiner,
            ROLE_REFINER
        );

        assertTrue(success);
        
        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(member.memberGIC, "GIFTCHZZ");
        assertEq(uint8(member.memberType), uint8(MemberRegistry.MemberType.COMPANY));
        assertEq(uint8(member.status), uint8(MemberRegistry.MemberStatus.ACTIVE));
        assertEq(member.userAddress, refiner);
        assertEq(member.roles, ROLE_REFINER);
    }

    function test_AssignRole() public {
        vm.prank(admin);
        registry.registerMember(
            "GIFTCHZZ",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash"),
            refiner,
            0
        );

        vm.prank(governance);
        bool success = registry.assignRole("GIFTCHZZ", ROLE_REFINER);

        assertTrue(success);
        
        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(member.roles & ROLE_REFINER, ROLE_REFINER);
    }

    function test_IsMemberInRole() public {
        vm.prank(admin);
        registry.registerMember(
            "GIFTCHZZ",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash"),
            refiner,
            ROLE_REFINER
        );

        bool hasRole = registry.isMemberInRole(refiner, ROLE_REFINER);
        assertTrue(hasRole);
    }

    function test_RevokeRole() public {
        vm.prank(admin);
        registry.registerMember(
            "GIFTCHZZ",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash"),
            refiner,
            ROLE_REFINER
        );

        vm.prank(governance);
        bool success = registry.revokeRole("GIFTCHZZ", ROLE_REFINER);

        assertTrue(success);
        
        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(member.roles & ROLE_REFINER, 0);
    }

    function test_SuspendMember() public {
        vm.prank(admin);
        registry.registerMember(
            "GIFTCHZZ",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash"),
            refiner,
            0
        );

        vm.prank(admin);
        bool success = registry.suspendMember("GIFTCHZZ", "Compliance violation");

        assertTrue(success);
        
        MemberRegistry.Member memory member = registry.getMemberDetails("GIFTCHZZ");
        assertEq(uint8(member.status), uint8(MemberRegistry.MemberStatus.SUSPENDED));
    }

    function test_RegisterUser() public {
        vm.prank(admin);
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
        vm.prank(admin);
        registry.registerMember(
            "GIFTCHZZ",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash"),
            refiner,
            0
        );

        vm.prank(admin);
        registry.registerUser(
            "USR-2025-00001",
            keccak256("user_hash")
        );

        vm.prank(admin);
        bool success = registry.linkUserToMember("USR-2025-00001", "GIFTCHZZ");

        assertTrue(success);
        
        MemberRegistry.User memory user = registry.getUserDetails("USR-2025-00001");
        assertEq(user.linkedMemberGIC, "GIFTCHZZ");
    }

    function test_AddUserAdminAddress() public {
        vm.prank(admin);
        registry.registerUser(
            "USR-2025-00001",
            keccak256("user_hash")
        );

        vm.prank(admin);
        bool success = registry.addUserAdminAddress("USR-2025-00001", refiner);

        assertTrue(success);
        
        MemberRegistry.User memory user = registry.getUserDetails("USR-2025-00001");
        assertEq(user.adminAddresses[0], refiner);
    }

    function test_SuspendUser() public {
        vm.prank(admin);
        registry.registerUser(
            "USR-2025-00001",
            keccak256("user_hash")
        );

        vm.prank(admin);
        bool success = registry.suspendUser("USR-2025-00001");

        assertTrue(success);
        
        MemberRegistry.User memory user = registry.getUserDetails("USR-2025-00001");
        assertEq(uint8(user.status), uint8(MemberRegistry.UserStatus.SUSPENDED));
    }

    function test_ActivateUser() public {
        vm.prank(admin);
        registry.registerUser(
            "USR-2025-00001",
            keccak256("user_hash")
        );

        vm.prank(admin);
        registry.suspendUser("USR-2025-00001");

        vm.prank(admin);
        bool success = registry.activateUser("USR-2025-00001");

        assertTrue(success);
        
        MemberRegistry.User memory user = registry.getUserDetails("USR-2025-00001");
        assertEq(uint8(user.status), uint8(MemberRegistry.UserStatus.ACTIVE));
    }

    function test_ValidatePermission() public {
        vm.prank(admin);
        registry.registerMember(
            "GIFTCHZZ",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash"),
            refiner,
            ROLE_REFINER
        );

        bool valid = registry.validatePermission(refiner, ROLE_REFINER);
        assertTrue(valid);
    }

    function test_OnlyGovernanceCanAssignRole() public {
        vm.prank(admin);
        registry.registerMember(
            "GIFTCHZZ",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash"),
            refiner,
            0
        );

        vm.prank(trader);
        vm.expectRevert("Not authorized: GOVERNANCE role required");
        registry.assignRole("GIFTCHZZ", ROLE_REFINER);
    }

    function test_GetMembersCount() public {
        vm.prank(admin);
        registry.registerMember(
            "GIFTCHZZ",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash"),
            refiner,
            0
        );

        vm.prank(admin);
        registry.registerMember(
            "GIFTUSAA",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member_hash2"),
            trader,
            0
        );

        assertEq(registry.getMembersCount(), 3); // +1 for PLATFORM
    }

    function test_GetUsersCount() public {
        vm.prank(admin);
        registry.registerUser("USR-2025-00001", keccak256("user_hash1"));

        vm.prank(admin);
        registry.registerUser("USR-2025-00002", keccak256("user_hash2"));

        assertEq(registry.getUsersCount(), 2);
    }
}
