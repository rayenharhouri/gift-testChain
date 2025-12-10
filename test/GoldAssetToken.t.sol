// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/GoldAssetToken.sol";

contract MockMemberRegistry {
    mapping(address => uint256) public roles;

    function setRole(address member, uint256 role) external {
        roles[member] = role;
    }

    function isMemberInRole(address member, uint256 role) external view returns (bool) {
        return (roles[member] & role) != 0;
    }

    function getMemberStatus(string memory memberGIC) external pure returns (uint8) {
        return 1; // ACTIVE
    }
}

contract GoldAssetTokenTest is Test {
    GoldAssetToken public goldToken;
    MockMemberRegistry public memberRegistry;
    
    address refiner = address(0x1);
    address custodian = address(0x2);
    address owner = address(0x3);
    address admin = address(0x4);

    uint256 constant ROLE_REFINER = 1 << 0;
    uint256 constant ROLE_CUSTODIAN = 1 << 2;
    uint256 constant ROLE_PLATFORM = 1 << 6;

    function setUp() public {
        memberRegistry = new MockMemberRegistry();
        goldToken = new GoldAssetToken(address(memberRegistry));

        // Set roles
        memberRegistry.setRole(refiner, ROLE_REFINER);
        memberRegistry.setRole(custodian, ROLE_CUSTODIAN);
        memberRegistry.setRole(admin, ROLE_PLATFORM);
    }

    function test_MintGoldAsset() public {
        vm.prank(refiner);
        
        uint256 tokenId = goldToken.mint(
            owner,
            "SN123456",
            "Refiner A",
            1000000, // 100 grams (scaled by 10^4)
            9999,    // 99.99% pure
            GoldAssetToken.GoldProductType.BAR,
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true
        );

        assertEq(tokenId, 1);
        
        GoldAssetToken.GoldAsset memory asset = goldToken.getAssetDetails(tokenId);
        assertEq(asset.serialNumber, "SN123456");
        assertEq(asset.refinerName, "Refiner A");
        assertEq(asset.weightGrams, 1000000);
        assertEq(asset.fineness, 9999);
        assertEq(asset.fineWeightGrams, 999900);
        assertEq(uint8(asset.status), uint8(GoldAssetToken.AssetStatus.REGISTERED));
    }

    function test_DuplicatePreventionFails() public {
        vm.prank(refiner);
        goldToken.mint(
            owner,
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            GoldAssetToken.GoldProductType.BAR,
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true
        );

        vm.prank(refiner);
        vm.expectRevert("Asset already registered");
        goldToken.mint(
            owner,
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            GoldAssetToken.GoldProductType.BAR,
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true
        );
    }

    function test_OnlyRefinerCanMint() public {
        vm.prank(owner);
        vm.expectRevert("Not authorized: REFINER role required");
        goldToken.mint(
            owner,
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            GoldAssetToken.GoldProductType.BAR,
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true
        );
    }

    function test_UpdateStatus() public {
        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            GoldAssetToken.GoldProductType.BAR,
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true
        );

        vm.prank(owner);
        goldToken.updateStatus(tokenId, GoldAssetToken.AssetStatus.IN_VAULT, "Stored in vault");

        GoldAssetToken.GoldAsset memory asset = goldToken.getAssetDetails(tokenId);
        assertEq(uint8(asset.status), uint8(GoldAssetToken.AssetStatus.IN_VAULT));
    }

    function test_BurnAsset() public {
        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            GoldAssetToken.GoldProductType.BAR,
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true
        );

        vm.prank(owner);
        goldToken.burn(tokenId, "Delivered to customer");

        GoldAssetToken.GoldAsset memory asset = goldToken.getAssetDetails(tokenId);
        assertEq(uint8(asset.status), uint8(GoldAssetToken.AssetStatus.BURNED));
    }

    function test_IsAssetLocked() public {
        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            GoldAssetToken.GoldProductType.BAR,
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true
        );

        assertFalse(goldToken.isAssetLocked(tokenId));

        vm.prank(owner);
        goldToken.updateStatus(tokenId, GoldAssetToken.AssetStatus.PLEDGED, "Pledged as collateral");

        assertTrue(goldToken.isAssetLocked(tokenId));
    }

    function test_VerifyCertificate() public {
        bytes32 certHash = keccak256("cert_hash");
        
        vm.prank(refiner);
        uint256 tokenId = goldToken.mint(
            owner,
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            GoldAssetToken.GoldProductType.BAR,
            certHash,
            "GIFTCHZZ",
            true
        );

        assertTrue(goldToken.verifyCertificate(tokenId, certHash));
        assertFalse(goldToken.verifyCertificate(tokenId, keccak256("wrong_hash")));
    }

    function test_GetAssetsByOwner() public {
        vm.prank(refiner);
        uint256 tokenId1 = goldToken.mint(
            owner,
            "SN123456",
            "Refiner A",
            1000000,
            9999,
            GoldAssetToken.GoldProductType.BAR,
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true
        );

        vm.prank(refiner);
        uint256 tokenId2 = goldToken.mint(
            owner,
            "SN789012",
            "Refiner B",
            500000,
            9999,
            GoldAssetToken.GoldProductType.COIN,
            keccak256("cert_hash2"),
            "GIFTCHZZ",
            true
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
            "SN123456",
            "Refiner A",
            10000, // 1 gram (scaled by 10^4)
            5000,  // 50% pure
            GoldAssetToken.GoldProductType.BAR,
            keccak256("cert_hash"),
            "GIFTCHZZ",
            true
        );

        GoldAssetToken.GoldAsset memory asset = goldToken.getAssetDetails(tokenId);
        assertEq(asset.fineWeightGrams, 5000); // 10000 * 5000 / 10000 = 5000
    }
}
