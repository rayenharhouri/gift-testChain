// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/DocumentRegistry.sol";

contract MockMemberRegistry is IMemberRegistry {
    mapping(address => uint256) public roles;

    function setRole(address member, uint256 role) external {
        roles[member] = role;
    }

    function isMemberInRole(
        address member,
        uint256 role
    ) external view returns (bool) {
        return (roles[member] & role) != 0;
    }

    function getMemberStatus(
        string memory
    ) external pure returns (uint8) {
        return 1;
    }

    function isBlacklisted(address) external pure returns (bool) {
        return false;
    }
}

contract DocumentRegistryTest is Test {
    DocumentRegistry public registry;
    MockMemberRegistry public memberRegistry;

    address uploader = address(0x1);
    address setRegistrar = address(0x2);
    address outsider = address(0x3);

    function setUp() public {
        memberRegistry = new MockMemberRegistry();
        registry = new DocumentRegistry(address(memberRegistry));

        memberRegistry.setRole(
            uploader,
            registry.ROLE_DOCUMENT_UPLOAD()
        );
        memberRegistry.setRole(
            setRegistrar,
            registry.ROLE_DOCUMENT_SET()
        );
    }

    function _registerDoc(
        address caller,
        string memory docId,
        string memory hash
    ) internal {
        vm.prank(caller);
        registry.registerDocument(
            docId,
            hash,
            "ipfs://doc",
            "CERT",
            "PDF",
            "MEMBER",
            "GIC-1",
            ""
        );
    }

    function test_RegisterDocument_Succeeds_And_Getters() public {
        _registerDoc(uploader, "DOC-1", "HASH-1");

        DocumentRegistry.Document memory doc =
            registry.getDocumentDetails("DOC-1");
        assertEq(doc.documentId, "DOC-1");
        assertEq(doc.fileHash, "HASH-1");
        assertEq(doc.documentType, "CERT");
        assertEq(doc.format, "PDF");
        assertEq(doc.ownerEntityType, "MEMBER");
        assertEq(doc.ownerEntityId, "GIC-1");
        assertEq(uint8(doc.status), uint8(DocumentRegistry.DocumentStatus.ACTIVE));
        assertTrue(doc.registeredAt > 0);

        assertEq(registry.getDocumentHash("DOC-1"), "HASH-1");
    }

    function test_RegisterDocument_Unauthorized_Reverts() public {
        vm.prank(outsider);
        vm.expectRevert("Not authorized: document upload role required");
        registry.registerDocument(
            "DOC-1",
            "HASH-1",
            "ipfs://doc",
            "CERT",
            "PDF",
            "MEMBER",
            "GIC-1",
            ""
        );
    }

    function test_UploadDocument_Succeeds() public {
        vm.prank(uploader);
        registry.uploadDocument(
            "DOC-2",
            "HASH-2",
            "ipfs://doc2",
            "AGREEMENT",
            "PDF",
            "MEMBER",
            "GIC-2",
            ""
        );
        assertEq(registry.getDocumentHash("DOC-2"), "HASH-2");
    }

    function test_RegisterDocumentSet_Succeeds() public {
        _registerDoc(uploader, "DOC-1", "HASH-1");
        _registerDoc(uploader, "DOC-2", "HASH-2");

        string[] memory docIds = new string[](2);
        docIds[0] = "DOC-1";
        docIds[1] = "DOC-2";

        vm.prank(setRegistrar);
        registry.registerDocumentSet(
            "SET-1",
            keccak256("root"),
            "MEMBER",
            "GIC-1",
            docIds
        );

        DocumentRegistry.DocumentSet memory set =
            registry.getDocumentSetDetails("SET-1");
        assertEq(set.setId, "SET-1");
        assertEq(set.documentIds.length, 2);
        assertEq(registry.getDocumentSetRootHash("SET-1"), keccak256("root"));
    }

    function test_RegisterDocumentSet_Reverts_WhenDocMissing() public {
        string[] memory docIds = new string[](1);
        docIds[0] = "DOC-404";

        vm.prank(setRegistrar);
        vm.expectRevert("Document does not exist");
        registry.registerDocumentSet(
            "SET-2",
            keccak256("root"),
            "MEMBER",
            "GIC-1",
            docIds
        );
    }

    function test_RegisterDocumentSet_Reverts_WhenDocAlreadyInSet() public {
        _registerDoc(uploader, "DOC-1", "HASH-1");

        string[] memory docIds = new string[](1);
        docIds[0] = "DOC-1";

        vm.prank(setRegistrar);
        registry.registerDocumentSet(
            "SET-1",
            keccak256("root"),
            "MEMBER",
            "GIC-1",
            docIds
        );

        vm.prank(setRegistrar);
        vm.expectRevert("Document already in set");
        registry.registerDocumentSet(
            "SET-2",
            keccak256("root2"),
            "MEMBER",
            "GIC-1",
            docIds
        );
    }

    function test_UploadDocumentBatch_Succeeds() public {
        string[] memory docIds = new string[](2);
        docIds[0] = "DOC-1";
        docIds[1] = "DOC-2";

        string[] memory hashes = new string[](2);
        hashes[0] = "HASH-1";
        hashes[1] = "HASH-2";

        string[] memory paths = new string[](2);
        paths[0] = "ipfs://doc1";
        paths[1] = "ipfs://doc2";

        string[] memory types = new string[](2);
        types[0] = "CERT";
        types[1] = "AGREEMENT";

        string[] memory formats = new string[](2);
        formats[0] = "PDF";
        formats[1] = "PDF";

        vm.prank(uploader);
        registry.uploadDocumentBatch(
            "SET-3",
            keccak256("root3"),
            "MEMBER",
            "GIC-1",
            docIds,
            hashes,
            paths,
            types,
            formats
        );

        assertEq(registry.getDocumentHash("DOC-1"), "HASH-1");
        assertEq(registry.getDocumentHash("DOC-2"), "HASH-2");

        DocumentRegistry.DocumentSet memory set =
            registry.getDocumentSetDetails("SET-3");
        assertEq(set.documentIds.length, 2);
    }

    function test_UploadDocumentBatch_Reverts_OnLengthMismatch() public {
        string[] memory docIds = new string[](1);
        docIds[0] = "DOC-1";

        string[] memory hashes = new string[](2);
        hashes[0] = "HASH-1";
        hashes[1] = "HASH-2";

        string[] memory paths = new string[](1);
        paths[0] = "ipfs://doc1";

        string[] memory types = new string[](1);
        types[0] = "CERT";

        string[] memory formats = new string[](1);
        formats[0] = "PDF";

        vm.prank(uploader);
        vm.expectRevert("Array length mismatch");
        registry.uploadDocumentBatch(
            "SET-4",
            keccak256("root4"),
            "MEMBER",
            "GIC-1",
            docIds,
            hashes,
            paths,
            types,
            formats
        );
    }

    function test_VerifyDocument_True_False() public {
        _registerDoc(uploader, "DOC-1", "HASH-1");

        assertTrue(registry.verifyDocument("DOC-1", "HASH-1"));
        assertFalse(registry.verifyDocument("DOC-1", "WRONG"));
        assertFalse(registry.verifyDocument("MISSING", "HASH-1"));
    }

    function test_VerifyDocumentAndLog_Emits() public {
        _registerDoc(uploader, "DOC-1", "HASH-1");

        vm.expectEmit(true, true, false, true);
        emit DocumentRegistry.DocumentVerified(
            "DOC-1",
            "HASH-1",
            true,
            block.timestamp
        );

        bool verified = registry.verifyDocumentAndLog("DOC-1", "HASH-1");
        assertTrue(verified);
    }

    function test_VerifyDocumentSet_SingleLeaf() public {
        _registerDoc(uploader, "DOC-1", "HASH-1");

        string[] memory docIds = new string[](1);
        docIds[0] = "DOC-1";

        bytes32 leaf = keccak256(abi.encodePacked("DOC-1", "HASH-1"));

        vm.prank(setRegistrar);
        registry.registerDocumentSet(
            "SET-5",
            leaf,
            "MEMBER",
            "GIC-1",
            docIds
        );

        bytes32[] memory proofWithLeaf = new bytes32[](1);
        proofWithLeaf[0] = leaf;
        assertTrue(registry.verifyDocumentSet("SET-5", proofWithLeaf));
    }

    function test_SupersedeDocument_And_Revoke() public {
        _registerDoc(uploader, "DOC-1", "HASH-1");
        _registerDoc(uploader, "DOC-2", "HASH-2");

        vm.prank(uploader);
        registry.supersedeDocument("DOC-1", "DOC-2");

        DocumentRegistry.Document memory doc1 =
            registry.getDocumentDetails("DOC-1");
        assertEq(uint8(doc1.status), uint8(DocumentRegistry.DocumentStatus.SUPERSEDED));
        assertFalse(registry.verifyDocument("DOC-1", "HASH-1"));

        vm.prank(uploader);
        registry.revokeDocument("DOC-2", "bad");

        DocumentRegistry.Document memory doc2 =
            registry.getDocumentDetails("DOC-2");
        assertEq(uint8(doc2.status), uint8(DocumentRegistry.DocumentStatus.REVOKED));
        assertFalse(registry.verifyDocument("DOC-2", "HASH-2"));

        vm.prank(uploader);
        vm.expectRevert("Already revoked");
        registry.revokeDocument("DOC-2", "bad");
    }

    function test_GetDocumentDetails_Reverts_WhenMissing() public {
        vm.expectRevert("Document not found");
        registry.getDocumentDetails("DOC-404");
    }

    function test_GetDocumentSetDetails_Reverts_WhenMissing() public {
        vm.expectRevert("Set not found");
        registry.getDocumentSetDetails("SET-404");
    }
}
