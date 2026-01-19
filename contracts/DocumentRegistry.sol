// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IMemberRegistry} from "./Interfaces/IMemberRegistry.sol";

/// @title DocumentRegistry
/// @notice On-chain registry for document hashes and document sets (Merkle roots).
/// @dev Designed for audit/compliance anchoring; does not store file contents.
contract DocumentRegistry is Ownable {
    /// @notice Bitmask for the PLATFORM role in the member registry.
    uint256 public constant ROLE_PLATFORM = 1 << 6;

    /// @notice MemberRegistry used to validate PLATFORM role.
    IMemberRegistry public memberRegistry;

    // -------------------------------------------------------------------------
    // Enums
    // -------------------------------------------------------------------------

    enum DocumentStatus {
        ACTIVE,
        SUPERSEDED,
        REVOKED
    }

    enum SetStatus {
        ACTIVE,
        SUPERSEDED
    }

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct Document {
        string documentId;
        bytes32 fileHash;
        string documentType;
        string format;
        string ownerEntityType;
        string ownerEntityId;
        DocumentStatus status;
        uint256 registeredAt;
        uint256 blockNumber;
    }

    struct DocumentSet {
        string setId;
        bytes32 rootHash;
        string ownerEntityType;
        string ownerEntityId;
        string[] documentIds;
        SetStatus status;
        uint256 registeredAt;
    }

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    mapping(string => Document) private documents;
    mapping(string => DocumentSet) private documentSets;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event DocumentRegistered(
        string indexed documentId,
        bytes32 indexed fileHash,
        string documentType,
        string format,
        string ownerEntityType,
        string ownerEntityId,
        uint256 timestamp,
        uint256 blockNumber
    );

    event DocumentSetRegistered(
        string indexed setId,
        bytes32 indexed rootHash,
        string ownerEntityType,
        string ownerEntityId,
        uint256 documentCount,
        uint256 timestamp
    );

    event DocumentVerified(
        string indexed documentId,
        bytes32 fileHash,
        bool verified,
        uint256 timestamp
    );

    event DocumentSuperseded(
        string indexed documentId,
        string indexed newDocumentId,
        uint256 timestamp
    );

    event DocumentRevoked(
        string indexed documentId,
        string reason,
        uint256 timestamp
    );

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyPlatform() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_PLATFORM),
            "Not authorized: PLATFORM role required"
        );
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _memberRegistry) Ownable(msg.sender) {
        require(_memberRegistry != address(0), "Invalid MemberRegistry");
        memberRegistry = IMemberRegistry(_memberRegistry);
    }

    // -------------------------------------------------------------------------
    // Document Management
    // -------------------------------------------------------------------------

    function registerDocument(
        string memory documentId,
        bytes32 fileHash,
        string memory documentType,
        string memory format,
        string memory ownerEntityType,
        string memory ownerEntityId
    ) external onlyPlatform {
        _registerDocument(
            documentId,
            fileHash,
            documentType,
            format,
            ownerEntityType,
            ownerEntityId
        );
    }

    /// @notice Alias for API alignment: POST /documents/upload
    function uploadDocument(
        string memory documentId,
        bytes32 fileHash,
        string memory documentType,
        string memory format,
        string memory ownerEntityType,
        string memory ownerEntityId
    ) external onlyPlatform {
        _registerDocument(
            documentId,
            fileHash,
            documentType,
            format,
            ownerEntityType,
            ownerEntityId
        );
    }

    function registerDocumentSet(
        string memory setId,
        bytes32 rootHash,
        string memory ownerEntityType,
        string memory ownerEntityId,
        string[] memory documentIds
    ) external onlyPlatform {
        _registerDocumentSet(
            setId,
            rootHash,
            ownerEntityType,
            ownerEntityId,
            documentIds
        );
    }


    /// @notice Batch upload multiple documents and register them as a set.
    /// @dev Mirrors single upload but accepts arrays for document fields.
    function uploadDocumentBatch(
        string memory setId,
        bytes32 rootHash,
        string memory ownerEntityType,
        string memory ownerEntityId,
        string[] memory documentIds,
        bytes32[] memory fileHashes,
        string[] memory documentTypes,
        string[] memory formats
    ) external onlyPlatform {
        require(documentIds.length > 0, "Empty documentIds");
        require(
            documentIds.length == fileHashes.length &&
                documentIds.length == documentTypes.length &&
                documentIds.length == formats.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < documentIds.length; i++) {
            _registerDocument(
                documentIds[i],
                fileHashes[i],
                documentTypes[i],
                formats[i],
                ownerEntityType,
                ownerEntityId
            );
        }

        _registerDocumentSet(
            setId,
            rootHash,
            ownerEntityType,
            ownerEntityId,
            documentIds
        );
    }

    // -------------------------------------------------------------------------
    // Verification
    // -------------------------------------------------------------------------

    function verifyDocument(
        string memory documentId,
        bytes32 fileHash
    ) external view returns (bool) {
        return _verifyDocument(documentId, fileHash);
    }

    /// @notice Optional logged verification for audit trails.
    function verifyDocumentAndLog(
        string memory documentId,
        bytes32 fileHash
    ) external returns (bool verified) {
        verified = _verifyDocument(documentId, fileHash);
        emit DocumentVerified(documentId, fileHash, verified, block.timestamp);
    }

    /**
     * @notice Verifies a leaf against the stored Merkle root for a set.
     * @dev `merkleProof` must be [leaf, proof...] where leaf is
     *      keccak256(abi.encodePacked(documentId, fileHash)) or another agreed
     *      leaf construction used off-chain to build `rootHash`.
     */
    function verifyDocumentSet(
        string memory setId,
        bytes32[] memory merkleProof
    ) external view returns (bool) {
        DocumentSet storage set = documentSets[setId];
        if (set.registeredAt == 0) {
            return false;
        }
        if (set.status != SetStatus.ACTIVE) {
            return false;
        }
        if (merkleProof.length == 0) {
            return false;
        }

        bytes32 leaf = merkleProof[0];
        bytes32[] memory proof = new bytes32[](merkleProof.length - 1);
        for (uint256 i = 1; i < merkleProof.length; i++) {
            proof[i - 1] = merkleProof[i];
        }

        return MerkleProof.verify(proof, set.rootHash, leaf);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function getDocumentDetails(
        string memory documentId
    ) external view returns (Document memory) {
        require(documents[documentId].registeredAt != 0, "Document not found");
        return documents[documentId];
    }

    /// @notice API alignment: GET /documents/{id}/hash
    function getDocumentHash(
        string memory documentId
    ) external view returns (bytes32) {
        require(documents[documentId].registeredAt != 0, "Document not found");
        return documents[documentId].fileHash;
    }

    function getDocumentSetDetails(
        string memory setId
    ) external view returns (DocumentSet memory) {
        require(documentSets[setId].registeredAt != 0, "Set not found");
        return documentSets[setId];
    }

    // -------------------------------------------------------------------------
    // Status Management
    // -------------------------------------------------------------------------

    function supersedeDocument(
        string memory documentId,
        string memory newDocumentId
    ) external onlyPlatform {
        Document storage doc = documents[documentId];
        require(doc.registeredAt != 0, "Document not found");
        require(doc.status == DocumentStatus.ACTIVE, "Document not active");
        require(
            documents[newDocumentId].registeredAt != 0,
            "New document not found"
        );
        require(
            documents[newDocumentId].status == DocumentStatus.ACTIVE,
            "New document not active"
        );

        doc.status = DocumentStatus.SUPERSEDED;

        emit DocumentSuperseded(documentId, newDocumentId, block.timestamp);
    }

    function revokeDocument(
        string memory documentId,
        string memory reason
    ) external onlyPlatform {
        Document storage doc = documents[documentId];
        require(doc.registeredAt != 0, "Document not found");
        require(doc.status != DocumentStatus.REVOKED, "Already revoked");

        doc.status = DocumentStatus.REVOKED;

        emit DocumentRevoked(documentId, reason, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    function _registerDocument(
        string memory documentId,
        bytes32 fileHash,
        string memory documentType,
        string memory format,
        string memory ownerEntityType,
        string memory ownerEntityId
    ) internal {
        require(bytes(documentId).length > 0, "Invalid documentId");
        require(fileHash != bytes32(0), "Invalid fileHash");
        require(bytes(documentType).length > 0, "Invalid documentType");
        require(bytes(format).length > 0, "Invalid format");
        require(bytes(ownerEntityType).length > 0, "Invalid ownerEntityType");
        require(bytes(ownerEntityId).length > 0, "Invalid ownerEntityId");
        require(
            documents[documentId].registeredAt == 0,
            "Document already exists"
        );

        documents[documentId] = Document({
            documentId: documentId,
            fileHash: fileHash,
            documentType: documentType,
            format: format,
            ownerEntityType: ownerEntityType,
            ownerEntityId: ownerEntityId,
            status: DocumentStatus.ACTIVE,
            registeredAt: block.timestamp,
            blockNumber: block.number
        });

        emit DocumentRegistered(
            documentId,
            fileHash,
            documentType,
            format,
            ownerEntityType,
            ownerEntityId,
            block.timestamp,
            block.number
        );
    }

    function _registerDocumentSet(
        string memory setId,
        bytes32 rootHash,
        string memory ownerEntityType,
        string memory ownerEntityId,
        string[] memory documentIds
    ) internal {
        require(bytes(setId).length > 0, "Invalid setId");
        require(rootHash != bytes32(0), "Invalid rootHash");
        require(bytes(ownerEntityType).length > 0, "Invalid ownerEntityType");
        require(bytes(ownerEntityId).length > 0, "Invalid ownerEntityId");
        require(documentIds.length > 0, "Empty documentIds");
        require(
            documentSets[setId].registeredAt == 0,
            "Document set already exists"
        );

        for (uint256 i = 0; i < documentIds.length; i++) {
            Document storage doc = documents[documentIds[i]];
            require(doc.registeredAt != 0, "Document does not exist");
            require(doc.status == DocumentStatus.ACTIVE, "Document not active");
        }

        DocumentSet storage set = documentSets[setId];
        set.setId = setId;
        set.rootHash = rootHash;
        set.ownerEntityType = ownerEntityType;
        set.ownerEntityId = ownerEntityId;
        set.documentIds = documentIds;
        set.status = SetStatus.ACTIVE;
        set.registeredAt = block.timestamp;

        emit DocumentSetRegistered(
            setId,
            rootHash,
            ownerEntityType,
            ownerEntityId,
            documentIds.length,
            block.timestamp
        );
    }

    function _verifyDocument(
        string memory documentId,
        bytes32 fileHash
    ) internal view returns (bool) {
        Document storage doc = documents[documentId];
        if (doc.registeredAt == 0) {
            return false;
        }
        if (doc.status != DocumentStatus.ACTIVE) {
            return false;
        }
        return doc.fileHash == fileHash;
    }
}
