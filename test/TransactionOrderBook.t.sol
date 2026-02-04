// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/TransactionOrderBook.sol";

contract TransactionOrderBookTest is Test {
    MemberRegistry public registry;
    TransactionOrderBook public orderBook;

    address initiator = address(0x1);
    address counterparty = address(0x2);

    uint256 constant ROLE_GMO = (1 << 6) | (1 << 7);

    function setUp() public {
        registry = new MemberRegistry();
        orderBook = new TransactionOrderBook(address(registry));

        // Register both parties as GMO members so they can sign.
        registry.registerMember(
            "INITIATOR",
            MemberRegistry.MemberType.COMPANY,
            keccak256("initiator"),
            initiator,
            ROLE_GMO
        );
        registry.registerMember(
            "COUNTERPARTY",
            MemberRegistry.MemberType.COMPANY,
            keccak256("counterparty"),
            counterparty,
            ROLE_GMO
        );
    }

    function test_PrepareSignFlow() public {
        TransactionOrderBook.RequestedAsset[] memory req =
            new TransactionOrderBook.RequestedAsset[](1);
        req[0] = TransactionOrderBook.RequestedAsset({
            goldProductTypeId: "BAR",
            quantityGrams: 1000
        });

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(initiator);
        string memory txRef = orderBook.prepareOrder(
            "TX-001",
            "TX-001",
            TransactionOrderBook.TransactionType.TRANSFER,
            "INITIATOR",
            "COUNTERPARTY",
            "IGAN-1",
            "IGAN-2",
            tokenIds,
            req,
            "2026-02-04",
            "USD",
            100,
            0,
            hex"01"
        );

        assertEq(
            uint8(orderBook.getOrderStatus(txRef)),
            uint8(TransactionOrderBook.TransactionStatus.PENDING_COUNTERPARTY)
        );

        vm.prank(counterparty);
        orderBook.signOrder(txRef, hex"02", "counterparty");

        assertEq(
            uint8(orderBook.getOrderStatus(txRef)),
            uint8(TransactionOrderBook.TransactionStatus.PENDING_EXECUTION)
        );
    }

    function test_CounterpartyCannotSignBeforePrepare() public {
        TransactionOrderBook.RequestedAsset[] memory req =
            new TransactionOrderBook.RequestedAsset[](1);
        req[0] = TransactionOrderBook.RequestedAsset({
            goldProductTypeId: "BAR",
            quantityGrams: 1000
        });

        uint256[] memory tokenIds = new uint256[](0);

        vm.prank(initiator);
        string memory txRef = orderBook.createOrder(
            "TX-002",
            "TX-002",
            TransactionOrderBook.TransactionType.TRANSFER,
            "INITIATOR",
            "COUNTERPARTY",
            tokenIds,
            req,
            "2026-02-04",
            "USD",
            100,
            0,
            "IGAN-1",
            "IGAN-2"
        );

        vm.prank(counterparty);
        vm.expectRevert("Not ready");
        orderBook.signOrder(txRef, hex"01", "counterparty");
    }
}
