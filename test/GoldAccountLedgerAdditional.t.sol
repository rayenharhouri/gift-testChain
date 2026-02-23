// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/GoldAccountLedger.sol";
import "../contracts/MemberRegistry.sol";

contract GoldAccountLedgerAdditionalTest is Test {
    GoldAccountLedger public ledger;
    MemberRegistry public registry;

    address platform = address(0x1);
    address ownerAddress = address(0x2);

    function setUp() public {
        vm.startPrank(platform);
        registry = new MemberRegistry();
        ledger = new GoldAccountLedger(address(registry));

        registry.registerMember(
            "MEMBER-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("member"),
            ownerAddress,
            0
        );
        vm.stopPrank();
    }

    function test_GetAccountDetails_ReturnsCreatedAccount() public {
        vm.prank(platform);
        ledger.createAccount(
            "IGAN-1000",
            "MEMBER-001",
            "VS-001",
            "GDA-1",
            "trading",
            0,
            "",
            ownerAddress
        );

        GoldAccountLedger.Account memory account =
            ledger.getAccountDetails("IGAN-1000");

        assertEq(account.igan, "IGAN-1000");
        assertEq(account.memberGIC, "MEMBER-001");
        assertEq(account.ownerAddress, ownerAddress);
        assertEq(account.vaultSiteId, "VS-001");
        assertEq(account.guaranteeDepositAccount, "GDA-1");
        assertEq(account.goldAccountPurpose, "trading");
        assertEq(account.initialDeposit, 0);
        assertEq(account.balance, 0);
        assertTrue(account.active);
    }

    function test_GetAccountDetails_Reverts_WhenAccountMissing() public {
        vm.expectRevert("Account does not exist");
        ledger.getAccountDetails("IGAN-404");
    }
}
