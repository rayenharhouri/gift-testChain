// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MemberRegistry.sol";

contract MemberRegistryHarness is MemberRegistry {
    function setMemberStatusForTest(
        string memory memberGIC,
        MemberStatus status
    ) external {
        members[memberGIC].status = status;
    }
}

contract MemberRegistryAdditionalTest is Test {
    MemberRegistryHarness public registry;

    address admin = address(this);
    address memberUser = address(0x1);
    address outsider = address(0x2);

    uint256 constant ROLE_TRADER = 1 << 8;

    function setUp() public {
        registry = new MemberRegistryHarness();
    }

    function test_Blacklist_Add_Remove_Set_And_IsBlacklisted() public {
        assertFalse(registry.isBlacklisted(memberUser));

        bool added = registry.addToBlacklist(memberUser);
        assertTrue(added);
        assertTrue(registry.isBlacklisted(memberUser));

        bool removed = registry.removeFromBlacklist(memberUser);
        assertTrue(removed);
        assertFalse(registry.isBlacklisted(memberUser));

        bool setTrue = registry.setBlacklisted(memberUser, true);
        assertTrue(setTrue);
        assertTrue(registry.isBlacklisted(memberUser));
    }

    function test_Blacklist_Functions_OnlyGmo() public {
        vm.prank(outsider);
        vm.expectRevert("Not authorized: GMO role required");
        registry.addToBlacklist(memberUser);

        vm.prank(outsider);
        vm.expectRevert("Not authorized: GMO role required");
        registry.removeFromBlacklist(memberUser);

        vm.prank(outsider);
        vm.expectRevert("Not authorized: GMO role required");
        registry.setBlacklisted(memberUser, true);
    }

    function test_ApproveMember_Reverts_WhenNotPending() public {
        registry.registerMember(
            "MEM-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("m1"),
            memberUser,
            ROLE_TRADER
        );

        vm.expectRevert("Member not pending");
        registry.approveMember("MEM-001");
    }

    function test_ApproveMember_Succeeds_WhenPending() public {
        registry.registerMember(
            "MEM-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("m1"),
            memberUser,
            ROLE_TRADER
        );
        registry.setMemberStatusForTest(
            "MEM-001",
            MemberRegistry.MemberStatus.PENDING
        );

        bool ok = registry.approveMember("MEM-001");
        assertTrue(ok);
        assertEq(
            registry.getMemberStatus("MEM-001"),
            uint8(MemberRegistry.MemberStatus.ACTIVE)
        );
    }

    function test_TerminateMember_SetsStatus() public {
        registry.registerMember(
            "MEM-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("m1"),
            memberUser,
            ROLE_TRADER
        );

        bool ok = registry.terminateMember("MEM-001");
        assertTrue(ok);
        assertEq(
            registry.getMemberStatus("MEM-001"),
            uint8(MemberRegistry.MemberStatus.TERMINATED)
        );
    }

    function test_GetMemberStatus_ReturnsCurrentStatus() public {
        registry.registerMember(
            "MEM-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("m1"),
            memberUser,
            ROLE_TRADER
        );
        assertEq(
            registry.getMemberStatus("MEM-001"),
            uint8(MemberRegistry.MemberStatus.ACTIVE)
        );
    }

    function test_GetUserStatus_ReturnsCurrentStatus() public {
        registry.registerUser("USR-1", keccak256("u1"));
        assertEq(
            registry.getUserStatus("USR-1"),
            uint8(MemberRegistry.UserStatus.ACTIVE)
        );

        registry.suspendUser("USR-1");
        assertEq(
            registry.getUserStatus("USR-1"),
            uint8(MemberRegistry.UserStatus.SUSPENDED)
        );
    }

    function test_GetMyRoles_ReturnsRolesForActiveMember() public {
        registry.registerMember(
            "MEM-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("m1"),
            memberUser,
            ROLE_TRADER
        );

        vm.prank(memberUser);
        assertEq(registry.getMyRoles(), ROLE_TRADER);
    }

    function test_GetMyRoles_ReturnsZero_IfMemberNotActive() public {
        registry.registerMember(
            "MEM-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("m1"),
            memberUser,
            ROLE_TRADER
        );
        registry.suspendMember("MEM-001", "suspend");

        vm.prank(memberUser);
        assertEq(registry.getMyRoles(), 0);
    }
}
