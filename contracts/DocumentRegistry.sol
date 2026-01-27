// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IMemberRegistry} from "./Interfaces/IMemberRegistry.sol";

/// @title DocumentRegistry
/// @notice On-chain registry for document hashes and document sets (Merkle roots).
/// @dev Designed for audit/compliance anchoring; does not store file contents.
contract DocumentRegistry is Ownable {
    /// @notice Role bitmasks aligned to the access matrix.
    uint256 public constant ROLE_REFINER = 1 << 0;
    uint256 public constant ROLE_MINTER = 1 << 1;
    uint256 public constant ROLE_VAULT = (1 << 2) | (1 << 3);
    uint256 public constant ROLE_LSP = 1 << 4;
    uint256 public constant ROLE_GMO = (1 << 6) | (1 << 7);
    uint256 public constant ROLE_TRADER = 1 << 8;
    uint256 public constant ROLE_DOCUMENT_UPLOAD =
        ROLE_REFINER | ROLE_MINTER | ROLE_TRADER | ROLE_VAULT | ROLE_LSP | ROLE_GMO;
    uint256 public constant ROLE_DOCUMENT_SET =
        ROLE_REFINER | ROLE_MINTER | ROLE_TRADER | ROLE_LSP | ROLE_GMO;

    /// @notice MemberRegistry used to validate role-based access.
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
        string fileHash;
        string offChainPath;
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
    mapping(string => string) private documentToSet;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event DocumentRegistered(
        string indexed documentId,
        string indexed fileHash,
        string offChainPath,
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
        string fileHash,
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

    modifier onlyDocumentUploader() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_DOCUMENT_UPLOAD),
            "Not authorized: document upload role required"
        );
        _;
    }

    modifier onlyDocumentSetRegistrar() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_DOCUMENT_SET),
            "Not authorized: document set role required"
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
        string memory fileHash,
        string memory offChainPath,
        string memory documentType,
        string memory format,
        string memory ownerEntityType,
        string memory ownerEntityId,
        string memory setId
    ) external onlyDocumentUploader {
        _registerDocument(
            documentId,
            fileHash,
            offChainPath,
            documentType,
            format,
            ownerEntityType,
            ownerEntityId
        );
        _addDocumentToSet(
            setId,
            documentId
        );
    }

    /// @notice Optional setId adds the document to an existing set.
    function uploadDocument(
        string memory documentId,
        string memory fileHash,
        string memory offChainPath,
        string memory documentType,
        string memory format,
        string memory ownerEntityType,
        string memory ownerEntityId,
        string memory setId
    ) external onlyDocumentUploader {
        _registerDocument(
            documentId,
            fileHash,
            offChainPath,
            documentType,
            format,
            ownerEntityType,
            ownerEntityId
        );
        _addDocumentToSet(
            setId,
            documentId
        );
    }

    function registerDocumentSet(
        string memory setId,
        bytes32 rootHash,
        string memory ownerEntityType,
        string memory ownerEntityId,
        string[] memory documentIds
    ) external onlyDocumentSetRegistrar {
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
        string[] memory fileHashes,
        string[] memory offChainPaths,
        string[] memory documentTypes,
        string[] memory formats
    ) external onlyDocumentUploader {
        require(documentIds.length > 0, "Empty documentIds");
        require(
            documentIds.length == fileHashes.length &&
                documentIds.length == offChainPaths.length &&
                documentIds.length == documentTypes.length &&
                documentIds.length == formats.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < documentIds.length; i++) {
            _registerDocument(
                documentIds[i],
                fileHashes[i],
                offChainPaths[i],
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
        string memory fileHash
    ) external view returns (bool) {
        return _verifyDocument(documentId, fileHash);
    }

    /// @notice Optional logged verification for audit trails.
    function verifyDocumentAndLog(
        string memory documentId,
        string memory fileHash
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
    ) external view returns (string memory) {
        require(documents[documentId].registeredAt != 0, "Document not found");
        return documents[documentId].fileHash;
    }

    function getDocumentSetDetails(
        string memory setId
    ) external view returns (DocumentSet memory) {
        require(documentSets[setId].registeredAt != 0, "Set not found");
        return documentSets[setId];
    }

    function getDocumentSetRootHash(
        string memory setId
    ) external view returns (bytes32) {
        require(documentSets[setId].registeredAt != 0, "Set not found");
        return documentSets[setId].rootHash;
    }

    // -------------------------------------------------------------------------
    // Status Management
    // -------------------------------------------------------------------------

    function supersedeDocument(
        string memory documentId,
        string memory newDocumentId
    ) external onlyDocumentUploader {
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
    ) external onlyDocumentUploader {
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
        string memory fileHash,
        string memory offChainPath,
        string memory documentType,
        string memory format,
        string memory ownerEntityType,
        string memory ownerEntityId
    ) internal {
        require(bytes(documentId).length > 0, "Invalid documentId");
        require(bytes(fileHash).length > 0, "Invalid fileHash");
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
            offChainPath: offChainPath,
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
            offChainPath,
            documentType,
            format,
            ownerEntityType,
            ownerEntityId,
            block.timestamp,
            block.number
        );
    }

    function _addDocumentToSet(
        string memory setId,
        string memory documentId
    ) internal {
        if (bytes(documentToSet[documentId]).length != 0) {
            revert("Document already in set");
        }
        if (bytes(setId).length == 0) {
            return;
        }

        DocumentSet storage set = documentSets[setId];
        require(set.registeredAt != 0, "Document set not found");


        if (!_documentInSet(set.documentIds, documentId)) {
            set.documentIds.push(documentId);
            documentToSet[documentId] = setId;
        }
    }

    function _documentInSet(
        string[] storage documentIds,
        string memory documentId
    ) internal view returns (bool) {
        for (uint256 i = 0; i < documentIds.length; i++) {
            if (
                keccak256(bytes(documentIds[i])) ==
                keccak256(bytes(documentId))
            ) {
                return true;
            }
        }
        return false;
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
            require(
                bytes(documentToSet[documentIds[i]]).length == 0,
                "Document already in set"
            );
        }

        DocumentSet storage set = documentSets[setId];
        set.setId = setId;
        set.rootHash = rootHash;
        set.ownerEntityType = ownerEntityType;
        set.ownerEntityId = ownerEntityId;
        set.documentIds = documentIds;
        set.status = SetStatus.ACTIVE;
        set.registeredAt = block.timestamp;

        for (uint256 i = 0; i < documentIds.length; i++) {
            documentToSet[documentIds[i]] = setId;
        }

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
        string memory fileHash
    ) internal view returns (bool) {
        Document storage doc = documents[documentId];
        if (doc.registeredAt == 0) {
            return false;
        }
        if (doc.status != DocumentStatus.ACTIVE) {
            return false;
        }
        return
            keccak256(bytes(doc.fileHash)) == keccak256(bytes(fileHash));
    }
}
