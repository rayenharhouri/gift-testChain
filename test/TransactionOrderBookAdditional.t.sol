// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/TransactionOrderBook.sol";

contract TransactionOrderBookAdditionalTest is Test {
    MemberRegistry public registry;
    TransactionOrderBook public orderBook;

    address initiator = address(0x1);
    address counterparty = address(0x2);
    address outsider = address(0x3);

    uint256 constant ROLE_GMO = (1 << 6) | (1 << 7);

    function setUp() public {
        registry = new MemberRegistry();
        orderBook = new TransactionOrderBook(address(registry));

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

    function _requestedAssets()
        internal
        pure
        returns (TransactionOrderBook.RequestedAsset[] memory req)
    {
        req = new TransactionOrderBook.RequestedAsset[](1);
        req[0] = TransactionOrderBook.RequestedAsset({
            goldProductTypeId: "BAR",
            quantityGrams: 1000
        });
    }

    function _createOrder() internal returns (string memory txRef) {
        TransactionOrderBook.RequestedAsset[] memory req = _requestedAssets();
        uint256[] memory tokenIds = new uint256[](0);

        vm.prank(initiator);
        txRef = orderBook.createOrder(
            "TX-ADD-001",
            "TX-ADD-001",
            TransactionOrderBook.TransactionType.TRANSFER,
            "INITIATOR",
            "COUNTERPARTY",
            tokenIds,
            req,
            "2026-02-13",
            "USD",
            120,
            0,
            "IGAN-1",
            "IGAN-2"
        );
    }

    function _prepareOrder() internal returns (string memory txRef) {
        TransactionOrderBook.RequestedAsset[] memory req = _requestedAssets();
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(initiator);
        txRef = orderBook.prepareOrder(
            "TX-ADD-002",
            "TX-ADD-002",
            TransactionOrderBook.TransactionType.TRANSFER,
            "INITIATOR",
            "COUNTERPARTY",
            "IGAN-1",
            "IGAN-2",
            tokenIds,
            req,
            "2026-02-13",
            "USD",
            120,
            0,
            "USR-INIT-001",
            hex"0102"
        );
    }

    function _prepareAndSign() internal returns (string memory txRef) {
        txRef = _prepareOrder();
        vm.prank(counterparty);
        orderBook.signOrder(txRef, hex"0304", "counterparty");
    }

    function test_SetMemberRegistry_OnlyOwner_And_Updates() public {
        MemberRegistry newRegistry = new MemberRegistry();

        vm.prank(outsider);
        vm.expectRevert();
        orderBook.setMemberRegistry(address(newRegistry));

        orderBook.setMemberRegistry(address(newRegistry));
        assertEq(address(orderBook.memberRegistry()), address(newRegistry));

        vm.expectRevert("Invalid MemberRegistry");
        orderBook.setMemberRegistry(address(0));
    }

    function test_SetGoldAccountLedger_OnlyOwner() public {
        vm.prank(outsider);
        vm.expectRevert();
        orderBook.setGoldAccountLedger(address(0x1234));

        orderBook.setGoldAccountLedger(address(0x1234));
        assertEq(address(orderBook.accountLedger()), address(0x1234));
    }

    function test_SetGoldAssetToken_OnlyOwner() public {
        vm.prank(outsider);
        vm.expectRevert();
        orderBook.setGoldAssetToken(address(0x5678));

        orderBook.setGoldAssetToken(address(0x5678));
        assertEq(address(orderBook.goldAssetToken()), address(0x5678));
    }

    function test_SetMinSignatures_OnlyOwner_And_ValueGuard() public {
        vm.prank(outsider);
        vm.expectRevert();
        orderBook.setMinSignatures(2);

        vm.expectRevert("Invalid minSignatures");
        orderBook.setMinSignatures(1);

        orderBook.setMinSignatures(2);
        assertEq(orderBook.minSignatures(), 2);
    }

    function test_SetExecutionOptions_OnlyOwner() public {
        vm.prank(outsider);
        vm.expectRevert();
        orderBook.setExecutionOptions(true, true);

        orderBook.setExecutionOptions(true, true);
        assertTrue(orderBook.transferAssetsOnExecute());
        assertTrue(orderBook.updateLedgerOnExecute());
    }

    function test_CancelOrder_SetsStatus() public {
        string memory txRef = _createOrder();

        vm.prank(initiator);
        orderBook.cancelOrder(txRef, "user cancelled");

        assertEq(
            uint8(orderBook.getOrderStatus(txRef)),
            uint8(TransactionOrderBook.TransactionStatus.CANCELLED)
        );
    }

    function test_FailOrder_SetsStatus() public {
        string memory txRef = _createOrder();

        vm.prank(initiator);
        orderBook.failOrder(txRef, "failed by check");

        assertEq(
            uint8(orderBook.getOrderStatus(txRef)),
            uint8(TransactionOrderBook.TransactionStatus.FAILED)
        );
    }

    function test_UpdateOrderStatus_Executed_SetsExecutedAt() public {
        string memory txRef = _prepareAndSign();

        vm.prank(initiator);
        orderBook.updateOrderStatus(
            txRef,
            TransactionOrderBook.TransactionStatus.EXECUTED,
            ""
        );

        TransactionOrderBook.TransactionOrder memory order =
            orderBook.getOrderDetails(txRef);

        assertEq(
            uint8(order.status),
            uint8(TransactionOrderBook.TransactionStatus.EXECUTED)
        );
        assertGt(order.executedAt, 0);
    }

    function test_UpdateOrderStatus_InvalidTransition_Reverts() public {
        string memory txRef = _createOrder();

        vm.prank(initiator);
        vm.expectRevert("Invalid status change");
        orderBook.updateOrderStatus(
            txRef,
            TransactionOrderBook.TransactionStatus.EXECUTED,
            ""
        );
    }

    function test_GetOrderDetails_And_GetOrderSignatures() public {
        string memory txRef = _prepareOrder();

        TransactionOrderBook.TransactionOrder memory order =
            orderBook.getOrderDetails(txRef);
        assertEq(order.transactionRef, "TX-ADD-002");
        assertEq(order.initiatorGIC, "INITIATOR");
        assertEq(order.counterpartyGIC, "COUNTERPARTY");
        assertEq(order.tokenIds.length, 1);

        TransactionOrderBook.Signature[] memory sigs =
            orderBook.getOrderSignatures(txRef);
        assertEq(sigs.length, 1);
        assertEq(sigs[0].signer, initiator);
        assertEq(sigs[0].signerUserId, "USR-INIT-001");
        assertEq(sigs[0].signerRole, "initiator");
    }
}
