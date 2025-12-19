// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/GoldAccountLedger.sol";
import "../contracts/MemberRegistry.sol";

contract GoldAccountLedgerTest is Test {
    GoldAccountLedger public ledger;
    MemberRegistry public registry;
    
    address public platform = address(1);
    address public custodian = address(2);
    address public user1 = address(3);
    
    function setUp() public {
        vm.startPrank(platform);
        
        registry = new MemberRegistry();
        ledger = new GoldAccountLedger(address(registry));
        
        registry.registerMember("CUSTODIAN-001", MemberRegistry.MemberType.COMPANY, keccak256("custodian"), custodian, 1 << 2);
        
        vm.stopPrank();
    }
    
    function testCreateAccount() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);
        
        assertEq(bytes(igan).length > 0, true);
        assertEq(ledger.getAccountBalance(igan), 0);
    }
    
    function testUpdateBalance() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);
        
        vm.prank(platform);
        ledger.updateBalance(igan, 10, "mint", 1);
        
        assertEq(ledger.getAccountBalance(igan), 10);
    }
    
    function testGetAccountsByMember() public {
        vm.startPrank(platform);
        
        ledger.createAccount("MEMBER-001", user1);
        ledger.createAccount("MEMBER-001", user1);
        
        string[] memory accounts = ledger.getAccountsByMember("MEMBER-001");
        assertEq(accounts.length, 2);
        
        vm.stopPrank();
    }
    
    function testUnauthorizedCannotCreateAccount() public {
        vm.prank(user1);
        vm.expectRevert("Not authorized: PLATFORM role required");
        ledger.createAccount("MEMBER-001", user1);
    }
    
    function testCustodianCanUpdateBalance() public {
        vm.prank(platform);
        string memory igan = ledger.createAccount("MEMBER-001", user1);
        
        vm.prank(custodian);
        ledger.updateBalance(igan, 5, "adjustment", 1);
        
        assertEq(ledger.getAccountBalance(igan), 5);
    }
}
