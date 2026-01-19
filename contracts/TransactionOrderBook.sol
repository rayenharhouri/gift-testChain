// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IDocumentRegistry} from "./Interfaces/IDocumentRegistry.sol";
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
    IDocumentRegistry public documentRegistry;
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
        COLLATERAL,
        PLEDGE,
        RELEASE,
        DELIVERY
    }

    enum TransactionStatus {
        DRAFT,
        PENDING_PREPARATION,
        PREPARED,
        PENDING_SIGNATURE,
        SIGNED,
        PENDING_EXECUTION,
        EXECUTED,
        CANCELLED,
        FAILED,
        EXPIRED
    }

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

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
        uint256 totalWeightGrams;
        uint256 totalFineWeightGrams;
        uint256 transactionValue;
        string currency;
        bytes32 orderDataHash;
        string documentSetId;
        uint256 createdAt;
        uint256 expiresAt;
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
        string senderIGAN,
        string receiverIGAN,
        string initiatorGIC,
        string counterpartyGIC,
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

    function setDocumentRegistry(address _documentRegistry) external onlyOwner {
        documentRegistry = IDocumentRegistry(_documentRegistry);
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
        string memory senderIGAN,
        string memory receiverIGAN,
        uint256[] memory tokenIds,
        uint256 totalWeightGrams,
        uint256 totalFineWeightGrams,
        uint256 transactionValue,
        string memory currency,
        bytes32 orderDataHash,
        string memory documentSetId,
        uint256 expiresAt
    ) external callerNotBlacklisted returns (string memory txRef) {
        txRef = _createOrder(
            transactionRef,
            transactionId,
            txType,
            initiatorGIC,
            counterpartyGIC,
            senderIGAN,
            receiverIGAN,
            tokenIds,
            totalWeightGrams,
            totalFineWeightGrams,
            transactionValue,
            currency,
            orderDataHash,
            documentSetId,
            expiresAt
        );
    }

    /// @notice Minimal API-friendly constructor: POST /transactions/create
    function createOrderSimple(
        string memory transactionRef,
        TransactionType txType,
        string memory senderIGAN,
        string memory receiverIGAN,
        uint256[] memory tokenIds,
        uint256 expiresAt
    ) external callerNotBlacklisted returns (string memory txRef) {
        txRef = _createOrder(
            transactionRef,
            "",
            txType,
            "",
            "",
            senderIGAN,
            receiverIGAN,
            tokenIds,
            0,
            0,
            0,
            "",
            bytes32(0),
            "",
            expiresAt
        );
    }

    function prepareOrder(
        string memory txRef,
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
            order.status == TransactionStatus.DRAFT ||
                order.status == TransactionStatus.PENDING_PREPARATION,
            "Invalid status"
        );

        if (tokenIds.length > 0) {
            order.tokenIds = tokenIds;
        }
        require(order.tokenIds.length > 0, "Missing tokenIds");

        order.status = TransactionStatus.PREPARED;
        emit OrderPrepared(txRef, order.tokenIds.length, block.timestamp);
    }

    function signOrder(
        string memory txRef,
        bytes memory signature
    ) external callerNotBlacklisted {
        _signOrder(txRef, signature, "");
    }

    function signOrderWithRole(
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

        require(order.status == TransactionStatus.SIGNED, "Not signed");
        require(order.tokenIds.length > 0, "Missing tokenIds");

        if (transferAssetsOnExecute) {
            _transferAssets(order);
        }

        if (updateLedgerOnExecute) {
            _updateLedgerBalances(order);
        }

        order.status = TransactionStatus.EXECUTED;
        emit OrderExecuted(txRef, order.tokenIds.length, block.timestamp);
    }

    function cancelOrder(
        string memory txRef,
        string memory reason
    ) external callerNotBlacklisted {
        TransactionOrder storage order = orders[txRef];
        require(order.createdAt != 0, "Order not found");
        require(
            msg.sender == order.createdBy || _isPlatform(msg.sender),
            "Not authorized"
        );
        require(
            order.status != TransactionStatus.EXECUTED &&
                order.status != TransactionStatus.CANCELLED &&
                order.status != TransactionStatus.FAILED &&
                order.status != TransactionStatus.EXPIRED,
            "Already closed"
        );

        order.status = TransactionStatus.CANCELLED;
        emit OrderCancelled(txRef, reason, block.timestamp);
    }

    function failOrder(
        string memory txRef,
        string memory reason
    ) external callerNotBlacklisted {
        TransactionOrder storage order = orders[txRef];
        require(order.createdAt != 0, "Order not found");
        require(_isPlatform(msg.sender), "Not authorized");
        require(
            order.status != TransactionStatus.EXECUTED &&
                order.status != TransactionStatus.CANCELLED &&
                order.status != TransactionStatus.FAILED &&
                order.status != TransactionStatus.EXPIRED,
            "Already closed"
        );

        order.status = TransactionStatus.FAILED;
        emit OrderFailed(txRef, reason, block.timestamp);
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

    function _createOrder(
        string memory transactionRef,
        string memory transactionId,
        TransactionType txType,
        string memory initiatorGIC,
        string memory counterpartyGIC,
        string memory senderIGAN,
        string memory receiverIGAN,
        uint256[] memory tokenIds,
        uint256 totalWeightGrams,
        uint256 totalFineWeightGrams,
        uint256 transactionValue,
        string memory currency,
        bytes32 orderDataHash,
        string memory documentSetId,
        uint256 expiresAt
    ) internal returns (string memory txRef) {
        require(bytes(transactionRef).length > 0, "Invalid transactionRef");
        require(orders[transactionRef].createdAt == 0, "Order exists");
        require(bytes(senderIGAN).length > 0, "Invalid senderIGAN");
        require(bytes(receiverIGAN).length > 0, "Invalid receiverIGAN");

        if (bytes(initiatorGIC).length > 0) {
            require(
                memberRegistry.getMemberStatus(initiatorGIC) == MEMBER_ACTIVE,
                "Initiator not active"
            );
        }
        if (bytes(counterpartyGIC).length > 0) {
            require(
                memberRegistry.getMemberStatus(counterpartyGIC) ==
                    MEMBER_ACTIVE,
                "Counterparty not active"
            );
        }

        if (expiresAt != 0) {
            require(expiresAt > block.timestamp, "Invalid expiresAt");
        }

        _validateDocumentSet(documentSetId);
        _validateAccounts(senderIGAN, receiverIGAN);

        orders[transactionRef] = TransactionOrder({
            transactionRef: transactionRef,
            transactionId: transactionId,
            txType: txType,
            status: TransactionStatus.DRAFT,
            initiatorGIC: initiatorGIC,
            counterpartyGIC: counterpartyGIC,
            senderIGAN: senderIGAN,
            receiverIGAN: receiverIGAN,
            tokenIds: tokenIds,
            totalWeightGrams: totalWeightGrams,
            totalFineWeightGrams: totalFineWeightGrams,
            transactionValue: transactionValue,
            currency: currency,
            orderDataHash: orderDataHash,
            documentSetId: documentSetId,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            createdBy: msg.sender
        });

        emit OrderCreated(
            transactionRef,
            transactionId,
            txType,
            senderIGAN,
            receiverIGAN,
            initiatorGIC,
            counterpartyGIC,
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
            order.status == TransactionStatus.PREPARED ||
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
            order.status = TransactionStatus.SIGNED;
        } else {
            order.status = TransactionStatus.PENDING_SIGNATURE;
        }

        emit OrderSigned(
            txRef,
            msg.sender,
            memberRegistry.addressToUserId(msg.sender),
            signerRole,
            block.timestamp
        );
    }

    function _validateDocumentSet(string memory documentSetId) internal view {
        if (bytes(documentSetId).length == 0) {
            return;
        }
        require(
            address(documentRegistry) != address(0),
            "DocumentRegistry not set"
        );
        documentRegistry.getDocumentSetDetails(documentSetId);
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
        if (order.status == TransactionStatus.EXPIRED) {
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
