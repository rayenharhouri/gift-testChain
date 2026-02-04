// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/GoldAssetToken.sol";

contract MockMemberRegistry {
    mapping(address => uint256) public roles;
    mapping(address => bool) public blacklisted;

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
        string memory /* memberGIC */
    ) external pure returns (uint8) {
        // Always ACTIVE for tests
        return 1;
    }

    function setBlacklisted(address account, bool status) external {
        blacklisted[account] = status;
    }

    function isBlacklisted(address account) external view returns (bool) {
        return blacklisted[account];
    }
}

contract MockAccountLedger {
    struct Call {
        string igan;
        int256 delta;
        string reason;
        uint256 tokenId;
    }

    Call[] public calls;

    /// @dev This should NEVER be used by GoldAssetToken in the new design.
    function updateBalance(
        string memory,
        int256,
        string memory,
        uint256
    ) external pure {
        revert("updateBalance should not be used");
    }

    function updateBalanceFromContract(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) external {
        calls.push(Call({igan: igan, delta: delta, reason: reason, tokenId: tokenId}));
    }

    function callsLength() external view returns (uint256) {
        return calls.length;
    }
}

contract GoldAssetTokenTest is Test {
    GoldAssetToken public goldToken;
    MockMemberRegistry public memberRegistry;
    MockAccountLedger public accountLedger;

    address refiner = address(0x1);
    address custodian = address(0x2);
    address owner = address(0x3);
    address admin = address(0x4);

    uint256 constant ROLE_REFINER = 1 << 0;
    uint256 constant ROLE_CUSTODIAN = 1 << 2;
    uint256 constant ROLE_PLATFORM = 1 << 6;

    function setUp() public {
        memberRegistry = new MockMemberRegistry();
        accountLedger = new MockAccountLedger();
        goldToken = new GoldAssetToken(
            address(memberRegistry),
            address(accountLedger)
        );

        // Set roles
        memberRegistry.setRole(refiner, ROLE_REFINER);
        memberRegistry.setRole(custodian, ROLE_CUSTODIAN);
        memberRegistry.setRole(admin, ROLE_PLATFORM);
    }

    function test_MintGoldAsset() public {
        string memory igan = "IGAN-1000";

        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            igan,
            "SN123456",
            "Refiner A",
            1000000, // 100 grams (scaled by 10^4)
            9999,    // 99.99% pure
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        assertEq(tokenId, 1);

        GoldAssetToken.GoldAsset memory asset = goldToken.getAssetDetails(
            tokenId
        );
        assertEq(asset.serialNumber, "SN123456");
        assertEq(asset.refinerName, "Refiner A");
        assertEq(asset.weightGrams, 1000000);
        assertEq(asset.fineness, 9999);
        assertEq(asset.fineWeightGrams, 999900);
        assertEq(
            uint8(asset.status),
            uint8(GoldAssetToken.AssetStatus.REGISTERED)
        );
        assertEq(asset.igan, igan);

        // Ledger should have one call: +1 MINT for IGAN-1000
        assertEq(accountLedger.callsLength(), 1);
        (string memory ledgerIgan, int256 delta, string memory reason, uint256 ledgerTokenId) =
            accountLedger.calls(0);
        assertEq(ledgerIgan, igan);
        assertEq(delta, int256(1));
        assertEq(reason, "MINT");
        assertEq(ledgerTokenId, tokenId);
    }

    function test_DuplicateSerialAllowed() public {
        vm.prank(refiner);
        uint256 t1 = goldToken.mint(
            owner,
            "IGAN-1000",
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        vm.prank(refiner);
        uint256 t2 = goldToken.mint(
            owner,
            "IGAN-1001",
            "SN123456", // same serialNumber + refinerName => duplicate
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash2"),
            "GIFTCHZZ",
            true,
            "WARRANT-002"
        );
        assertEq(t1, 1);
        assertEq(t2, 2);
    }

    function test_OnlyRefinerOrMinterCanMint() public {
        vm.prank(owner);
        vm.expectRevert("Not authorized: REFINER or MINTER role required");
        goldToken.mint(
            owner,
            "IGAN-1000",
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );
    }

    function test_UpdateStatus() public {
        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            "IGAN-1000",
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        vm.prank(owner);
        goldToken.updateStatus(
            tokenId,
            GoldAssetToken.AssetStatus.IN_VAULT,
            "Stored in vault"
        );

        GoldAssetToken.GoldAsset memory asset = goldToken.getAssetDetails(
            tokenId
        );
        assertEq(
            uint8(asset.status),
            uint8(GoldAssetToken.AssetStatus.IN_VAULT)
        );
    }

    function test_BurnAsset_UpdatesLedgerWithStoredIgan() public {
        string memory igan = "IGAN-1000";

        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            igan,
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        // one ledger call from mint
        assertEq(accountLedger.callsLength(), 1);

        vm.prank(refiner);
        // accountId argument is ignored in implementation; IGAN comes from stored asset
        goldToken.burn(tokenId, "SOME-OTHER-IGAN", "Delivered to customer");

        GoldAssetToken.GoldAsset memory asset = goldToken.getAssetDetails(
            tokenId
        );
        assertEq(uint8(asset.status), uint8(GoldAssetToken.AssetStatus.BURNED));

        // second ledger call from burn
        assertEq(accountLedger.callsLength(), 2);
        (string memory ledgerIgan, int256 delta, string memory reason, uint256 ledgerTokenId) =
            accountLedger.calls(1);
        assertEq(ledgerIgan, igan);          // must match stored igan, not the param
        assertEq(delta, int256(-1));
        assertEq(reason, "Delivered to customer");
        assertEq(ledgerTokenId, tokenId);
    }

    function test_IsAssetLocked() public {
        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            "IGAN-1000",
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        assertFalse(goldToken.isAssetLocked(tokenId));

        vm.prank(owner);
        goldToken.updateStatus(
            tokenId,
            GoldAssetToken.AssetStatus.PLEDGED,
            "Pledged as collateral"
        );

        assertTrue(goldToken.isAssetLocked(tokenId));
    }

    function test_VerifyCertificate() public {
        bytes32 certHash = keccak256("cert_hash");

        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            "IGAN-1000",
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            certHash,
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        assertTrue(goldToken.verifyCertificate(tokenId, certHash));
        assertFalse(
            goldToken.verifyCertificate(tokenId, keccak256("wrong_hash"))
        );
    }

    function test_GetAssetsByOwner() public {
        vm.prank(refiner);
        uint256 tokenId1 = goldToken.mint(
            owner,
            "IGAN-1000",
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        vm.prank(refiner);
        uint256 tokenId2 = goldToken.mint(
            owner,
            "IGAN-1001",
            "SN789012",
            "Refiner B",
            500000,
            9999,
            "COIN",
            keccak256("cert_hash2"),
            "GIFTCHZZ",
            true,
            "WARRANT-002"
        );

        uint256[] memory assets = goldToken.getAssetsByOwner(owner);
        assertEq(assets.length, 2);
        assertEq(assets[0], tokenId1);
        assertEq(assets[1], tokenId2);
    }

    function test_FineWeightCalculation() public {
        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            "IGAN-1000",
            "SN123456",
            "Refiner A",
            10000, // 1 gram (scaled by 10^4)
            5000,  // 50% pure
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        GoldAssetToken.GoldAsset memory asset = goldToken.getAssetDetails(
            tokenId
        );
        // 10000 * 5000 / 10000 = 5000
        assertEq(asset.fineWeightGrams, 5000);
    }

    function test_WarrantDuplicatePrevention() public {
        vm.prank(refiner);
        goldToken.mint(
            owner,
            "IGAN-1000",
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        vm.prank(refiner);
        vm.expectRevert("Warrant already used");
        goldToken.mint(
            owner,
            "IGAN-1001",
            "SN789012",
            "Refiner B",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash2"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );
    }

    function test_ForceTransfer() public {
        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            "IGAN-1000",
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );

        address newOwner = address(0x5);
        vm.prank(admin);
        goldToken.forceTransfer(tokenId, owner, newOwner, "Compliance action");

        assertEq(goldToken.assetOwner(tokenId), newOwner);
    }

    function _mintOne() internal returns (uint256 tokenId) {
        vm.prank(refiner);
        tokenId = goldToken.mint(
            owner,
            "IGAN-1000",
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            "BAR",
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true,
            "WARRANT-001"
        );
    }

    function test_Transfer_UpdatesAssetOwner_AndEmitsOwnershipUpdated() public {
        uint256 tokenId = _mintOne();
        address to = address(0xBEEF);

        uint256 t = 12345;
        vm.warp(t);

        // Expect business event for normal transfer
        vm.expectEmit(true, true, true, true);
        emit GoldAssetToken.OwnershipUpdated(tokenId, owner, to, "TRANSFER", t);

        vm.prank(owner);
        goldToken.safeTransferFrom(owner, to, tokenId, 1, "");

        // assetOwner must be synced
        assertEq(goldToken.assetOwner(tokenId), to);

        // balances reflect ERC1155 reality too
        assertEq(goldToken.balanceOf(owner, tokenId), 0);
        assertEq(goldToken.balanceOf(to, tokenId), 1);
    }

    function test_Transfer_Reverts_WhenEitherSideBlacklisted() public {
        uint256 tokenId = _mintOne();
        address to = address(0xBEEF);

        // blacklist recipient
        memberRegistry.setBlacklisted(to, true);

        vm.prank(owner);
        vm.expectRevert("Address blacklisted");
        goldToken.safeTransferFrom(owner, to, tokenId, 1, "");
    }

    function test_Transfer_Reverts_WhenAssetLocked_Pledged() public {
        uint256 tokenId = _mintOne();
        address to = address(0xBEEF);

        // lock it
        vm.prank(owner);
        goldToken.updateStatus(
            tokenId,
            GoldAssetToken.AssetStatus.PLEDGED,
            "Pledged"
        );

        vm.prank(owner);
        vm.expectRevert("Asset locked");
        goldToken.safeTransferFrom(owner, to, tokenId, 1, "");
    }

    function test_Transfer_Reverts_WhenAssetLocked_InTransit() public {
        uint256 tokenId = _mintOne();
        address to = address(0xBEEF);

        // lock it
        vm.prank(owner);
        goldToken.updateStatus(
            tokenId,
            GoldAssetToken.AssetStatus.IN_TRANSIT,
            "Shipping"
        );

        vm.prank(owner);
        vm.expectRevert("Asset locked");
        goldToken.safeTransferFrom(owner, to, tokenId, 1, "");
    }

    function test_UpdateCustodyBatch_SetsInTransit() public {
        uint256 tokenId = _mintOne();
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;

        vm.prank(custodian);
        goldToken.updateCustodyBatch(ids, address(0xBEEF), "direct");

        GoldAssetToken.GoldAsset memory asset = goldToken.getAssetDetails(
            tokenId
        );
        assertEq(
            uint8(asset.status),
            uint8(GoldAssetToken.AssetStatus.IN_TRANSIT)
        );
    }

    function test_OldOwnerCannotBurnOrUpdateStatusAfterTransfer() public {
        uint256 tokenId = _mintOne();
        address to = address(0xBEEF);

        vm.prank(owner);
        goldToken.safeTransferFrom(owner, to, tokenId, 1, "");

        // old owner tries to update status -> should fail because assetOwner changed
        vm.prank(owner);
        vm.expectRevert("Not authorized: asset operator role required");
        goldToken.updateStatus(
            tokenId,
            GoldAssetToken.AssetStatus.IN_VAULT,
            "No longer owner"
        );

        // old owner tries to burn -> should fail
        vm.prank(owner);
        vm.expectRevert("Not authorized: REFINER or MINTER role required");
        goldToken.burn(tokenId, "IGAN-1000", "No longer owner");
    }

    function test_ForceTransfer_BypassesWhitelist() public {
        uint256 tokenId = _mintOne();
        address to = address(0xBEEF);

        vm.prank(admin);
        goldToken.forceTransfer(tokenId, owner, to, "Compliance action");

        assertEq(goldToken.assetOwner(tokenId), to);
        assertEq(goldToken.balanceOf(to, tokenId), 1);
        assertEq(goldToken.balanceOf(owner, tokenId), 0);
    }

    function test_ForceTransfer_Reverts_WhenAssetLocked_WithCurrentUpdateLogic()
        public
    {
        uint256 tokenId = _mintOne();
        address to = address(0xBEEF);

        // lock it
        vm.prank(owner);
        goldToken.updateStatus(
            tokenId,
            GoldAssetToken.AssetStatus.PLEDGED,
            "Pledged"
        );

        // With current _update(), lock check is applied to all normal transfers
        // including forceTransfer (because from/to are non-zero).
        vm.prank(admin);
        vm.expectRevert("Asset locked");
        goldToken.forceTransfer(tokenId, owner, to, "Compliance action");
    }

    function test_VerifyCertificate_NonExistentToken_Reverts() public {
        vm.expectRevert("Asset does not exist");
        goldToken.verifyCertificate(999, bytes32(0));
    }

    function test_Burn_NonExistentToken_Reverts() public {
        // refiner can call burn, but the function will revert on missing asset.
        vm.prank(refiner);
        vm.expectRevert("Asset does not exist");
        goldToken.burn(999, "IGAN-1000", "Burn non-existent");
    }
}
