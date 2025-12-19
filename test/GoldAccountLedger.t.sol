// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/GoldAccountLedger.sol";
import "../contracts/MemberRegistry.sol";

contract GoldAccountLedgerTest is Test {
    GoldAccountLedger public ledger;
    MemberRegistry public registry;

    address public platform  = address(1);
    address public custodian = address(2);
    address public user1     = address(3);
    address public updater   = address(9);

    function setUp() public {
        vm.startPrank(platform);

        // Deploy registry/ledger as PLATFORM
        registry = new MemberRegistry();
        ledger = new GoldAccountLedger(address(registry));

        // Register members used by tests (so createAccount passes "Member not active")
        registry.registerMember(
            "MEMBER-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member-001"),
            user1,
            0
        );

        // Register custodian member (gives custodian ROLE_CUSTODIAN bit 1<<2)
        registry.registerMember(
            "CUSTODIAN-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("custodian"),
            custodian,
            1 << 2
        );

        vm.stopPrank();
    }

    function testCreateAccount() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        // First generated IGAN should start at 1000
        assertEq(igan, "IGAN-1000");
        assertEq(ledger.getAccountBalance(igan), 0);
    }

    function testCreateAccount_IncrementsIGAN() public {
        vm.startPrank(platform);

        string memory a1 = ledger.createAccount("MEMBER-001", user1);
        string memory a2 = ledger.createAccount("MEMBER-001", user1);

        vm.stopPrank();

        assertEq(a1, "IGAN-1000");
        assertEq(a2, "IGAN-1001");
    }

    function testCreateAccount_RevertsIfMemberNotActive() public {
        // Create MEMBER-002 then suspend it, then ledger should reject it
        vm.startPrank(platform);

        registry.registerMember(
            "MEMBER-002",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member-002"),
            address(0xAA),
            0
        );

        registry.suspendMember("MEMBER-002", "test suspend");

        vm.expectRevert("Member not active");
        ledger.createAccount("MEMBER-002", user1);

        vm.stopPrank();
    }

    function testUnauthorizedCannotCreateAccount() public {
        vm.prank(user1);
        vm.expectRevert("Not authorized: PLATFORM role required");
        ledger.createAccount("MEMBER-001", user1);
    }

    function testUpdateBalance_ByPlatform() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        vm.prank(platform);
        ledger.updateBalance(igan, 10, "mint", 1);

        assertEq(ledger.getAccountBalance(igan), 10);
    }

    function testCustodianCanUpdateBalance() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        vm.prank(custodian);
        ledger.updateBalance(igan, 5, "adjustment", 1);

        assertEq(ledger.getAccountBalance(igan), 5);
    }

    function testUpdateBalance_RevertsIfNotAuthorized() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        vm.prank(user1);
        vm.expectRevert("Not authorized");
        ledger.updateBalance(igan, 1, "nope", 1);
    }

    function testUpdateBalance_NegativeDelta_RevertsIfInsufficient() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        vm.prank(platform);
        vm.expectRevert("Insufficient balance");
        ledger.updateBalance(igan, -1, "withdraw", 1);
    }

    function testGetAccountBalance_RevertsIfAccountDoesNotExist() public {
        vm.expectRevert("Account does not exist");
        ledger.getAccountBalance("IGAN-9999");
    }

    function testUpdateBalance_RevertsIfAccountDoesNotExist() public {
        vm.prank(platform);
        vm.expectRevert("Account does not exist");
        ledger.updateBalance("IGAN-9999", 1, "mint", 1);
    }

    // ---- US-10 prep: allowlist smart contracts as balance updaters ----

    function testSetBalanceUpdater_OnlyPlatform() public {
        vm.prank(user1);
        vm.expectRevert("Not authorized: PLATFORM role required");
        ledger.setBalanceUpdater(updater, true);

        vm.prank(platform);
        ledger.setBalanceUpdater(updater, true);
    }

    function testUpdateBalanceFromContract_RevertsIfNotUpdater() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        vm.prank(updater);
        vm.expectRevert("Not authorized: updater");
        ledger.updateBalanceFromContract(igan, 1, "mint", 1);
    }

    function testUpdateBalanceFromContract_WorksWhenUpdaterAllowed() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        vm.prank(platform);
        ledger.setBalanceUpdater(updater, true);

        vm.prank(updater);
        ledger.updateBalanceFromContract(igan, 7, "mint", 1);

        assertEq(ledger.getAccountBalance(igan), 7);
    }

    function testGetAccountsByMember() public {
        vm.startPrank(platform);

        ledger.createAccount("MEMBER-001", user1);
        ledger.createAccount("MEMBER-001", user1);

        string[] memory accounts = ledger.getAccountsByMember("MEMBER-001");
        assertEq(accounts.length, 2);

        vm.stopPrank();
    }

    function testGetAccountsByAddress() public {
        vm.startPrank(platform);

        ledger.createAccount("MEMBER-001", user1);
        ledger.createAccount("MEMBER-001", user1);

        string[] memory accounts = ledger.getAccountsByAddress(user1);
        assertEq(accounts.length, 2);

        vm.stopPrank();
    }
        function test_Event_AccountCreated() public {
        uint256 t = 111;
        vm.warp(t);

        vm.expectEmit(true, true, true, true);
        emit GoldAccountLedger.AccountCreated("IGAN-1000", "MEMBER-001", user1, t);

        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        assertEq(igan, "IGAN-1000");
    }

    function test_Event_BalanceUpdated_Platform() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        uint256 t = 222;
        vm.warp(t);

        vm.expectEmit(true, true, true, true);
        emit GoldAccountLedger.BalanceUpdated(igan, int256(10), 10, "mint", 1, t);

        vm.prank(platform);
        ledger.updateBalance(igan, 10, "mint", 1);
    }

    function test_Event_BalanceUpdated_NegativeDelta() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        // Seed balance
        vm.prank(platform);
        ledger.updateBalance(igan, 10, "seed", 1);

        uint256 t = 333;
        vm.warp(t);

        vm.expectEmit(true, true, true, true);
        emit GoldAccountLedger.BalanceUpdated(igan, int256(-3), 7, "withdraw", 2, t);

        vm.prank(platform);
        ledger.updateBalance(igan, -3, "withdraw", 2);
    }

    function test_Event_BalanceUpdaterSet() public {
        uint256 t = 444;
        vm.warp(t);

        vm.expectEmit(true, true, true, true);
        emit GoldAccountLedger.BalanceUpdaterSet(updater, true, t);

        vm.prank(platform);
        ledger.setBalanceUpdater(updater, true);
    }

    function test_Event_BalanceUpdated_FromContractUpdater() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);

        vm.prank(platform);
        ledger.setBalanceUpdater(updater, true);

        uint256 t = 555;
        vm.warp(t);

        vm.expectEmit(true, true, true, true);
        emit GoldAccountLedger.BalanceUpdated(igan, int256(7), 7, "mint", 1, t);

        vm.prank(updater);
        ledger.updateBalanceFromContract(igan, 7, "mint", 1);
    }

}
