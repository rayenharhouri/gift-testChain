// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/GoldAssetToken.sol";

contract MockMemberRegistryGAT {
    mapping(address => uint256) public roles;
    mapping(address => bool) public blacklisted;

    function setRole(address member, uint256 role) external {
        roles[member] = role;
    }

    function setBlacklisted(address account, bool status) external {
        blacklisted[account] = status;
    }

    function isMemberInRole(
        address member,
        uint256 role
    ) external view returns (bool) {
        return (roles[member] & role) != 0;
    }

    function getMemberStatus(string memory) external pure returns (uint8) {
        return 1;
    }

    function isBlacklisted(address account) external view returns (bool) {
        return blacklisted[account];
    }
}

contract MockAccountLedgerGAT {
    function updateBalance(
        string memory,
        int256,
        string memory,
        uint256
    ) external pure {}

    function updateBalanceFromContract(
        string memory,
        int256,
        string memory,
        uint256
    ) external pure {}
}

contract GoldAssetTokenAdditionalTest is Test {
    GoldAssetToken public goldToken;
    MockMemberRegistryGAT public memberRegistry;
    MockAccountLedgerGAT public accountLedger;

    address refiner = address(0x1);
    address ownerAddr = address(0x2);
    address receiver = address(0x3);
    address admin = address(0x4);
    address outsider = address(0x5);

    uint256 constant ROLE_REFINER = 1 << 0;
    uint256 constant ROLE_GMO = (1 << 6) | (1 << 7);

    function setUp() public {
        memberRegistry = new MockMemberRegistryGAT();
        accountLedger = new MockAccountLedgerGAT();
        goldToken = new GoldAssetToken(
            address(memberRegistry),
            address(accountLedger)
        );

        memberRegistry.setRole(refiner, ROLE_REFINER);
        memberRegistry.setRole(admin, ROLE_GMO);
    }

    function _mintOne() internal returns (uint256 tokenId) {
        vm.prank(refiner);
        tokenId = goldToken.mint(
            ownerAddr,
            "IGAN-1000",
            "SN-1",
            "Refiner",
            1000000,
            9999,
            "BAR",
            keccak256("cert"),
            "GIC-1",
            true,
            "WARRANT-1"
        );
    }

    function test_TransferAsset_Works_ForTokenOwner() public {
        uint256 tokenId = _mintOne();

        vm.prank(ownerAddr);
        bool ok = goldToken.transferAsset(tokenId, receiver);
        assertTrue(ok);
        assertEq(goldToken.assetOwner(tokenId), receiver);
    }

    function test_TransferAsset_Reverts_WhenNotTokenOwner() public {
        uint256 tokenId = _mintOne();

        vm.prank(outsider);
        vm.expectRevert("Not token owner");
        goldToken.transferAsset(tokenId, receiver);
    }

    function test_TransferAsset_Reverts_WhenRecipientBlacklisted() public {
        uint256 tokenId = _mintOne();
        memberRegistry.setBlacklisted(receiver, true);

        vm.prank(ownerAddr);
        vm.expectRevert("Address blacklisted");
        goldToken.transferAsset(tokenId, receiver);
    }

    function test_AddRemoveBlacklist_OnlyGmo() public {
        vm.prank(outsider);
        vm.expectRevert("Not authorized: GMO role required");
        goldToken.addToBlacklist(receiver);

        vm.prank(outsider);
        vm.expectRevert("Not authorized: GMO role required");
        goldToken.removeFromBlacklist(receiver);

        vm.prank(admin);
        goldToken.addToBlacklist(receiver);

        vm.prank(admin);
        goldToken.removeFromBlacklist(receiver);
    }

    function test_IsWarrantUsed_And_GetTokenByWarrant() public {
        assertFalse(goldToken.isWarrantUsed("WARRANT-1"));

        vm.expectRevert("Warrant not used");
        goldToken.getTokenByWarrant("WARRANT-1");

        uint256 tokenId = _mintOne();
        assertTrue(goldToken.isWarrantUsed("WARRANT-1"));
        assertEq(goldToken.getTokenByWarrant("WARRANT-1"), tokenId);
    }

    function test_Uri_ReturnsIpfsPath() public {
        uint256 tokenId = _mintOne();
        string memory tokenUri = goldToken.uri(tokenId);
        assertEq(tokenUri, "ipfs://GIFT-ASSET-1");
    }

    function test_GetAssetStatus_ReturnsRegisteredAfterMint() public {
        uint256 tokenId = _mintOne();
        assertEq(
            uint8(goldToken.getAssetStatus(tokenId)),
            uint8(GoldAssetToken.AssetStatus.REGISTERED)
        );
    }

    function test_SetMemberRegistry_OnlyOwner_And_Validation() public {
        MockMemberRegistryGAT newRegistry = new MockMemberRegistryGAT();

        vm.prank(outsider);
        vm.expectRevert();
        goldToken.setMemberRegistry(address(newRegistry));

        goldToken.setMemberRegistry(address(newRegistry));
        assertEq(address(goldToken.memberRegistry()), address(newRegistry));

        vm.expectRevert("Invalid registry");
        goldToken.setMemberRegistry(address(0));
    }

    function test_SetAccountLedger_OnlyOwner() public {
        MockAccountLedgerGAT newLedger = new MockAccountLedgerGAT();

        vm.prank(outsider);
        vm.expectRevert();
        goldToken.setAccountLedger(address(newLedger));

        goldToken.setAccountLedger(address(newLedger));
        assertEq(address(goldToken.accountLedger()), address(newLedger));
    }
}
