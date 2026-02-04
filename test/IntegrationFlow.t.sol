// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/GoldAccountLedger.sol";
import "../contracts/GoldAssetToken.sol";
import "../contracts/TransactionOrderBook.sol";

contract IntegrationFlowTest is Test {
    MemberRegistry public registry;
    GoldAccountLedger public ledger;
    GoldAssetToken public token;
    TransactionOrderBook public orderBook;

    address initiator = address(0x1);
    address counterparty = address(0x2);

    uint256 constant ROLE_MINTER = 1 << 1;
    uint256 constant ROLE_GMO = (1 << 6) | (1 << 7);

    function setUp() public {
        registry = new MemberRegistry();
        ledger = new GoldAccountLedger(address(registry));
        token = new GoldAssetToken(address(registry), address(ledger));
        orderBook = new TransactionOrderBook(address(registry));

        orderBook.setGoldAccountLedger(address(ledger));
        orderBook.setGoldAssetToken(address(token));
        orderBook.setExecutionOptions(true, true);

        // Allow contract-based balance updates
        ledger.setBalanceUpdater(address(token), true);
        ledger.setBalanceUpdater(address(orderBook), true);

        // Register GMO members
        registry.registerMember(
            "INITIATOR",
            MemberRegistry.MemberType.COMPANY,
            keccak256("initiator"),
            initiator,
            ROLE_GMO | ROLE_MINTER
        );
        registry.registerMember(
            "COUNTERPARTY",
            MemberRegistry.MemberType.COMPANY,
            keccak256("counterparty"),
            counterparty,
            ROLE_GMO
        );

        // Create IGAN accounts
        ledger.createAccount(
            "IGAN-1",
            "INITIATOR",
            "VS-1",
            "GDA-1",
            "trading",
            0,
            "",
            initiator
        );
        ledger.createAccount(
            "IGAN-2",
            "COUNTERPARTY",
            "VS-1",
            "GDA-2",
            "custody",
            0,
            "",
            counterparty
        );
    }

    function test_EndToEnd_Flow() public {
        // Mint asset to initiator
        vm.prank(initiator);
        uint256 tokenId = token.mint(
            initiator,
            "IGAN-1",
            "SN-001",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        // Approve order book to transfer asset
        vm.prank(initiator);
        token.setApprovalForAll(address(orderBook), true);

        // Create order
        TransactionOrderBook.RequestedAsset[] memory req =
            new TransactionOrderBook.RequestedAsset[](1);
        req[0] = TransactionOrderBook.RequestedAsset({
            goldProductTypeId: "BAR",
            quantityGrams: 1000
        });
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.prank(initiator);
        string memory txRef = orderBook.createOrder(
            "TX-100",
            "TX-100",
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

        assertEq(
            uint8(orderBook.getOrderStatus(txRef)),
            uint8(TransactionOrderBook.TransactionStatus.PENDING_SIGNATURE)
        );

        // Sign by initiator then counterparty (both GMO)
        vm.prank(initiator);
        orderBook.signOrder(txRef, hex"01", "initiator");
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

        // Execute
        vm.prank(initiator);
        orderBook.executeOrder(txRef);
        assertEq(
            uint8(orderBook.getOrderStatus(txRef)),
            uint8(TransactionOrderBook.TransactionStatus.EXECUTED)
        );

        // Asset ownership moved to counterparty
        assertEq(token.assetOwner(tokenId), counterparty);

        // Ledger balances updated
        assertEq(ledger.getAccountBalance("IGAN-1"), 0);
        assertEq(ledger.getAccountBalance("IGAN-2"), 1);
    }
}
