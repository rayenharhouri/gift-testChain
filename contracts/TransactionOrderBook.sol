// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IGoldAccountLedger} from "./Interfaces/IGoldAccountLedger.sol";
import {IGoldAssetToken} from "./Interfaces/IGoldAssetToken.sol";
import {IMemberRegistryExtended} from "./Interfaces/IMemberRegistryExtended.sol";

/// @title TransactionOrderBook
/// @notice Tracks transaction orders and optional execution across assets and accounts.
/// @dev Combines fields from v4.0 API schedule and roadmap/spec notes.
contract TransactionOrderBook is Ownable {
    uint8 public constant MEMBER_ACTIVE = 1;
    uint256 public constant ROLE_PLATFORM = 1 << 6;

    IMemberRegistryExtended public memberRegistry;
    IGoldAccountLedger public accountLedger;
    IGoldAssetToken public goldAssetToken;

    uint256 public minSignatures = 1;
    bool public transferAssetsOnExecute = false;
    bool public updateLedgerOnExecute = false;

    // -------------------------------------------------------------------------
    // Enums
    // -------------------------------------------------------------------------

    enum TransactionType {
        TRANSFER,
        SALE,
        PURCHASE,
        COLLATERAL
    }

    enum TransactionStatus {
        PENDING_PREPARATION,
        PENDING_SIGNATURE,
        PENDING_EXECUTION,
        EXECUTED,
        CANCELLED,
        FAILED,
        EXPIRED
    }

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct RequestedAsset {
        string goldProductTypeId;
        uint256 quantityGrams;
    }

    struct TransactionOrder {
        string transactionRef;
        string transactionId;
        TransactionType txType;
        TransactionStatus status;
        string initiatorGIC;
        string counterpartyGIC;
        string senderIGAN;
        string receiverIGAN;
        uint256[] tokenIds;
        RequestedAsset[] requestedAssets;
        string valuationDate;
        string valuationCurrency;
        uint256 transactionValue;
        uint256 createdAt;
        uint256 expiresAt;
        uint256 executedAt;
        address createdBy;
    }

    struct Signature {
        address signer;
        string signerUserId;
        string signerRole;
        bytes signature;
        uint256 signedAt;
    }

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    mapping(string => TransactionOrder) private orders;
    mapping(string => Signature[]) private orderSignatures;
    mapping(string => mapping(address => bool)) private hasSigned;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event OrderCreated(
        string indexed transactionRef,
        string transactionId,
        TransactionType txType,
        string initiatorGIC,
        string counterpartyGIC,
        uint256 requestedAssetCount,
        string valuationCurrency,
        uint256 transactionValue,
        TransactionStatus status,
        uint256 timestamp,
        uint256 expiresAt
    );

    event OrderPrepared(
        string indexed transactionRef,
        uint256 tokenCount,
        uint256 timestamp
    );

    event OrderSigned(
        string indexed transactionRef,
        address indexed signer,
        string signerUserId,
        string signerRole,
        uint256 signaturesCollected,
        uint256 signaturesRequired,
        uint256 timestamp
    );

    event OrderExecuted(
        string indexed transactionRef,
        uint256 tokenCount,
        uint256 timestamp
    );

    event OrderCancelled(
        string indexed transactionRef,
        string reason,
        uint256 timestamp
    );

    event OrderFailed(
        string indexed transactionRef,
        string reason,
        uint256 timestamp
    );

    event OrderExpired(string indexed transactionRef, uint256 timestamp);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier callerNotBlacklisted() {
        require(!memberRegistry.isBlacklisted(msg.sender), "Caller blacklisted");
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _memberRegistry) Ownable(msg.sender) {
        require(_memberRegistry != address(0), "Invalid MemberRegistry");
        memberRegistry = IMemberRegistryExtended(_memberRegistry);
    }

    // -------------------------------------------------------------------------
    // Admin configuration
    // -------------------------------------------------------------------------

    function setMemberRegistry(address _memberRegistry) external onlyOwner {
        require(_memberRegistry != address(0), "Invalid MemberRegistry");
        memberRegistry = IMemberRegistryExtended(_memberRegistry);
    }

    function setGoldAccountLedger(address _accountLedger) external onlyOwner {
        accountLedger = IGoldAccountLedger(_accountLedger);
    }

    function setGoldAssetToken(address _goldAssetToken) external onlyOwner {
        goldAssetToken = IGoldAssetToken(_goldAssetToken);
    }

    function setMinSignatures(uint256 _minSignatures) external onlyOwner {
        require(_minSignatures > 0, "Invalid minSignatures");
        minSignatures = _minSignatures;
    }

    function setExecutionOptions(
        bool _transferAssetsOnExecute,
        bool _updateLedgerOnExecute
    ) external onlyOwner {
        transferAssetsOnExecute = _transferAssetsOnExecute;
        updateLedgerOnExecute = _updateLedgerOnExecute;
    }

    // -------------------------------------------------------------------------
    // Order lifecycle
    // -------------------------------------------------------------------------

    function createOrder(
        string memory transactionRef,
        string memory transactionId,
        TransactionType txType,
        string memory initiatorGIC,
        string memory counterpartyGIC,
        RequestedAsset[] memory requestedAssets,
        string memory valuationDate,
        string memory valuationCurrency,
        uint256 transactionValue,
        uint256 expiresAt
    ) external callerNotBlacklisted returns (string memory txRef) {
        txRef = _createOrder(
            transactionRef,
            transactionId,
            txType,
            initiatorGIC,
            counterpartyGIC,
            requestedAssets,
            valuationDate,
            valuationCurrency,
            transactionValue,
            expiresAt
        );
    }

    function prepareOrder(
        string memory txRef,
        string memory senderIGAN,
        string memory receiverIGAN,
        uint256[] memory tokenIds
    ) external callerNotBlacklisted {
        TransactionOrder storage order = orders[txRef];
        require(order.createdAt != 0, "Order not found");
        require(_callerIsParticipant(order), "Not authorized");

        if (_isExpired(order)) {
            _expireOrder(order);
            return;
        }

        require(
            order.status == TransactionStatus.PENDING_PREPARATION,
            "Invalid status"
        );

        require(bytes(senderIGAN).length > 0, "Invalid senderIGAN");
        require(bytes(receiverIGAN).length > 0, "Invalid receiverIGAN");
        order.senderIGAN = senderIGAN;
        order.receiverIGAN = receiverIGAN;
        _validateAccounts(senderIGAN, receiverIGAN);

        require(tokenIds.length > 0, "Missing tokenIds");
        order.tokenIds = tokenIds;

        order.status = TransactionStatus.PENDING_SIGNATURE;
        emit OrderPrepared(txRef, order.tokenIds.length, block.timestamp);
    }

    function signOrder(
        string memory txRef,
        bytes memory signature,
        string memory signerRole
    ) external callerNotBlacklisted {
        _signOrder(txRef, signature, signerRole);
    }

    function executeOrder(string memory txRef) external callerNotBlacklisted {
        TransactionOrder storage order = orders[txRef];
        require(order.createdAt != 0, "Order not found");
        require(_callerIsParticipant(order), "Not authorized");

        if (_isExpired(order)) {
            _expireOrder(order);
            return;
        }

        require(
            order.status == TransactionStatus.PENDING_EXECUTION,
            "Not ready"
        );
        require(bytes(order.senderIGAN).length > 0, "Missing senderIGAN");
        require(bytes(order.receiverIGAN).length > 0, "Missing receiverIGAN");
        require(order.tokenIds.length > 0, "Missing tokenIds");

        if (transferAssetsOnExecute) {
            _transferAssets(order);
        }

        if (updateLedgerOnExecute) {
            _updateLedgerBalances(order);
        }

        order.status = TransactionStatus.EXECUTED;
        order.executedAt = block.timestamp;
        emit OrderExecuted(txRef, order.tokenIds.length, block.timestamp);
    }

    function cancelOrder(
        string memory txRef,
        string memory reason
    ) external callerNotBlacklisted {
        _updateStatus(txRef, TransactionStatus.CANCELLED, reason);
    }

    function failOrder(
        string memory txRef,
        string memory reason
    ) external callerNotBlacklisted {
        _updateStatus(txRef, TransactionStatus.FAILED, reason);
    }

    function updateOrderStatus(
        string memory txRef,
        TransactionStatus newStatus,
        string memory reason
    ) external callerNotBlacklisted {
        _updateStatus(txRef, newStatus, reason);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function getOrderDetails(
        string memory txRef
    ) external view returns (TransactionOrder memory order) {
        require(orders[txRef].createdAt != 0, "Order not found");
        return orders[txRef];
    }

    function getOrderStatus(
        string memory txRef
    ) external view returns (TransactionStatus) {
        require(orders[txRef].createdAt != 0, "Order not found");
        return orders[txRef].status;
    }

    function getOrderSignatures(
        string memory txRef
    ) external view returns (Signature[] memory) {
        require(orders[txRef].createdAt != 0, "Order not found");
        return orderSignatures[txRef];
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    function _updateStatus(
        string memory txRef,
        TransactionStatus newStatus,
        string memory reason
    ) internal {
        TransactionOrder storage order = orders[txRef];
        require(order.createdAt != 0, "Order not found");
        require(
            _callerIsParticipant(order) || _isPlatform(msg.sender),
            "Not authorized"
        );
        if (_isExpired(order)) {
            _expireOrder(order);
            return;
        }
        _validateTransition(order.status, newStatus);

        if (
            newStatus == TransactionStatus.CANCELLED ||
            newStatus == TransactionStatus.FAILED
        ) {
            require(bytes(reason).length > 0, "Reason required");
        }

        order.status = newStatus;
        if (newStatus == TransactionStatus.EXECUTED) {
            order.executedAt = block.timestamp;
            emit OrderExecuted(txRef, order.tokenIds.length, block.timestamp);
            return;
        }
        if (newStatus == TransactionStatus.CANCELLED) {
            emit OrderCancelled(txRef, reason, block.timestamp);
            return;
        }
        if (newStatus == TransactionStatus.FAILED) {
            emit OrderFailed(txRef, reason, block.timestamp);
            return;
        }
        if (newStatus == TransactionStatus.EXPIRED) {
            emit OrderExpired(txRef, block.timestamp);
            return;
        }
    }

    function _validateTransition(
        TransactionStatus currentStatus,
        TransactionStatus newStatus
    ) internal pure {
        if (currentStatus == newStatus) {
            return;
        }
        if (currentStatus == TransactionStatus.EXECUTED) {
            revert("Already executed");
        }
        if (currentStatus == TransactionStatus.CANCELLED) {
            revert("Already cancelled");
        }
        if (currentStatus == TransactionStatus.FAILED) {
            revert("Already failed");
        }
        if (currentStatus == TransactionStatus.EXPIRED) {
            revert("Already expired");
        }

        if (currentStatus == TransactionStatus.PENDING_PREPARATION) {
            require(
                newStatus == TransactionStatus.PENDING_SIGNATURE ||
                    newStatus == TransactionStatus.CANCELLED ||
                    newStatus == TransactionStatus.FAILED ||
                    newStatus == TransactionStatus.EXPIRED,
                "Invalid status change"
            );
            return;
        }

        if (currentStatus == TransactionStatus.PENDING_SIGNATURE) {
            require(
                newStatus == TransactionStatus.PENDING_EXECUTION ||
                    newStatus == TransactionStatus.CANCELLED ||
                    newStatus == TransactionStatus.FAILED ||
                    newStatus == TransactionStatus.EXPIRED,
                "Invalid status change"
            );
            return;
        }

        if (currentStatus == TransactionStatus.PENDING_EXECUTION) {
            require(
                newStatus == TransactionStatus.EXECUTED ||
                    newStatus == TransactionStatus.CANCELLED ||
                    newStatus == TransactionStatus.FAILED ||
                    newStatus == TransactionStatus.EXPIRED,
                "Invalid status change"
            );
            return;
        }

        revert("Invalid status change");
    }

    function _createOrder(
        string memory transactionRef,
        string memory transactionId,
        TransactionType txType,
        string memory initiatorGIC,
        string memory counterpartyGIC,
        RequestedAsset[] memory requestedAssets,
        string memory valuationDate,
        string memory valuationCurrency,
        uint256 transactionValue,
        uint256 expiresAt
    ) internal returns (string memory txRef) {
        require(bytes(transactionRef).length > 0, "Invalid transactionRef");
        require(orders[transactionRef].createdAt == 0, "Order exists");
        require(bytes(initiatorGIC).length > 0, "Invalid initiatorGIC");
        require(bytes(counterpartyGIC).length > 0, "Invalid counterpartyGIC");
        require(requestedAssets.length > 0, "Missing requested assets");
        require(bytes(valuationDate).length > 0, "Invalid valuationDate");
        require(bytes(valuationCurrency).length > 0, "Invalid currency");

        for (uint256 i = 0; i < requestedAssets.length; i++) {
            require(
                bytes(requestedAssets[i].goldProductTypeId).length > 0,
                "Invalid product type"
            );
            require(
                requestedAssets[i].quantityGrams > 0,
                "Invalid quantity"
            );
        }

        require(
            memberRegistry.getMemberStatus(initiatorGIC) == MEMBER_ACTIVE,
            "Initiator not active"
        );
        require(
            memberRegistry.getMemberStatus(counterpartyGIC) == MEMBER_ACTIVE,
            "Counterparty not active"
        );

        if (expiresAt != 0) {
            require(expiresAt > block.timestamp, "Invalid expiresAt");
        }

        if (bytes(transactionId).length == 0) {
            transactionId = transactionRef;
        }

        orders[transactionRef] = TransactionOrder({
            transactionRef: transactionRef,
            transactionId: transactionId,
            txType: txType,
            status: TransactionStatus.PENDING_PREPARATION,
            initiatorGIC: initiatorGIC,
            counterpartyGIC: counterpartyGIC,
            senderIGAN: "",
            receiverIGAN: "",
            tokenIds: new uint256[](0),
            requestedAssets: requestedAssets,
            valuationDate: valuationDate,
            valuationCurrency: valuationCurrency,
            transactionValue: transactionValue,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            executedAt: 0,
            createdBy: msg.sender
        });

        emit OrderCreated(
            transactionRef,
            transactionId,
            txType,
            initiatorGIC,
            counterpartyGIC,
            requestedAssets.length,
            valuationCurrency,
            transactionValue,
            TransactionStatus.PENDING_PREPARATION,
            block.timestamp,
            expiresAt
        );

        return transactionRef;
    }

    function _signOrder(
        string memory txRef,
        bytes memory signature,
        string memory signerRole
    ) internal {
        TransactionOrder storage order = orders[txRef];
        require(order.createdAt != 0, "Order not found");
        require(_callerIsParticipant(order), "Not authorized");

        if (_isExpired(order)) {
            _expireOrder(order);
            return;
        }

        require(
            order.status == TransactionStatus.PENDING_SIGNATURE,
            "Invalid status"
        );
        require(!hasSigned[txRef][msg.sender], "Already signed");
        require(signature.length > 0, "Invalid signature");

        hasSigned[txRef][msg.sender] = true;
        orderSignatures[txRef].push(
            Signature({
                signer: msg.sender,
                signerUserId: memberRegistry.addressToUserId(msg.sender),
                signerRole: signerRole,
                signature: signature,
                signedAt: block.timestamp
            })
        );

        if (orderSignatures[txRef].length >= minSignatures) {
            order.status = TransactionStatus.PENDING_EXECUTION;
        }

        emit OrderSigned(
            txRef,
            msg.sender,
            memberRegistry.addressToUserId(msg.sender),
            signerRole,
            orderSignatures[txRef].length,
            minSignatures,
            block.timestamp
        );
    }

    function _validateAccounts(
        string memory senderIGAN,
        string memory receiverIGAN
    ) internal view {
        if (address(accountLedger) == address(0)) {
            return;
        }
        IGoldAccountLedger.Account memory sender = accountLedger
            .getAccountDetails(senderIGAN);
        IGoldAccountLedger.Account memory receiver = accountLedger
            .getAccountDetails(receiverIGAN);
        require(sender.active, "Sender account inactive");
        require(receiver.active, "Receiver account inactive");
    }

    function _transferAssets(TransactionOrder storage order) internal {
        require(
            address(goldAssetToken) != address(0),
            "GoldAssetToken not set"
        );
        require(
            address(accountLedger) != address(0),
            "GoldAccountLedger not set"
        );

        IGoldAccountLedger.Account memory sender = accountLedger
            .getAccountDetails(order.senderIGAN);
        IGoldAccountLedger.Account memory receiver = accountLedger
            .getAccountDetails(order.receiverIGAN);

        require(sender.ownerAddress != address(0), "Invalid sender address");
        require(receiver.ownerAddress != address(0), "Invalid receiver address");

        for (uint256 i = 0; i < order.tokenIds.length; i++) {
            uint256 tokenId = order.tokenIds[i];
            require(!goldAssetToken.isAssetLocked(tokenId), "Asset locked");
            goldAssetToken.safeTransferFrom(
                sender.ownerAddress,
                receiver.ownerAddress,
                tokenId,
                1,
                ""
            );
        }
    }

    function _updateLedgerBalances(TransactionOrder storage order) internal {
        require(
            address(accountLedger) != address(0),
            "GoldAccountLedger not set"
        );
        if (
            keccak256(bytes(order.senderIGAN)) ==
            keccak256(bytes(order.receiverIGAN))
        ) {
            return;
        }

        for (uint256 i = 0; i < order.tokenIds.length; i++) {
            uint256 tokenId = order.tokenIds[i];
            accountLedger.updateBalanceFromContract(
                order.senderIGAN,
                -1,
                "TRANSFER_OUT",
                tokenId
            );
            accountLedger.updateBalanceFromContract(
                order.receiverIGAN,
                1,
                "TRANSFER_IN",
                tokenId
            );
        }
    }

    function _isExpired(
        TransactionOrder storage order
    ) internal view returns (bool) {
        if (order.expiresAt == 0) {
            return false;
        }
        return block.timestamp > order.expiresAt;
    }

    function _expireOrder(TransactionOrder storage order) internal {
        if (
            order.status == TransactionStatus.EXPIRED ||
            order.status == TransactionStatus.EXECUTED ||
            order.status == TransactionStatus.CANCELLED ||
            order.status == TransactionStatus.FAILED
        ) {
            return;
        }
        order.status = TransactionStatus.EXPIRED;
        emit OrderExpired(order.transactionRef, block.timestamp);
    }

    function _callerIsParticipant(
        TransactionOrder storage order
    ) internal view returns (bool) {
        if (_isPlatform(msg.sender)) {
            return true;
        }
        string memory memberGIC = memberRegistry.addressToMemberGIC(msg.sender);
        if (bytes(memberGIC).length == 0) {
            return false;
        }
        return (keccak256(bytes(memberGIC)) ==
            keccak256(bytes(order.initiatorGIC)) ||
            keccak256(bytes(memberGIC)) ==
            keccak256(bytes(order.counterpartyGIC)));
    }

    function _isPlatform(address account) internal view returns (bool) {
        return memberRegistry.isMemberInRole(account, ROLE_PLATFORM);
    }
}
