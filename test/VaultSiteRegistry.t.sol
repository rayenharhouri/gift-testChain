// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/VaultSiteRegistry.sol";

contract VaultSiteRegistryTest is Test {
    MemberRegistry public memberRegistry;
    VaultSiteRegistry public vaultSiteRegistry;

    address platform = address(0x1);
    address memberWallet = address(0x2);
    address outsider = address(0x3);

    // --- Event copied exactly from VaultSiteRegistry ---
    event VaultSiteCreated(
        string indexed vaultSiteId,
        string indexed memberGIC,
        string vaultSiteName,
        string country,
        uint256 numberOfVaults,
        uint256 maximumWeightInGoldKg,
        string lastAuditDate,
        address indexed createdBy,
        uint256 timestamp
    );

    function setUp() public {
        memberRegistry = new MemberRegistry();

        // Make `platform` act as PLATFORM (owner == address(this) can bootstrap)
        memberRegistry.linkAddressToMember(platform, "PLATFORM");

        // Register operating member for vault site (ACTIVE by default in your registerMember)
        vm.prank(platform);
        memberRegistry.registerMember(
            "VAULTOP-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("vaultop-001"),
            memberWallet,
            0
        );

        vaultSiteRegistry = new VaultSiteRegistry(address(memberRegistry));
    }

    // -------------------------------------------------------------------------
    // Helper: NO cheatcodes inside (important for expectRevert correctness)
    // -------------------------------------------------------------------------
    function _createDefaultSite(
        string memory vaultSiteId
    ) internal returns (bool) {
        return
            vaultSiteRegistry.createVaultSite(
                vaultSiteId,
                "Zurich Prime Site",
                "VAULTOP-001",
                "Zurich Campus",
                "Bahnhofstrasse 1",
                "Bahnhofstrasse 1",
                "Zurich",
                "ZH",
                "8001",
                "CH",
                "Europe/Zurich",
                "47.3769,8.5417",
                3,
                50000,
                "Mon-Fri 09:00-17:00",
                "Zurich Insurance Co",
                "2026-12-31",
                "SOD-INS-001",
                "SOD-AUD-001",
                "2025-01-15"
            );
    }

    // -------------------------------------------------------------------------
    // Normal cases
    // -------------------------------------------------------------------------

    function test_CreateVaultSite_AsPlatform_Succeeds() public {
        uint256 t = 111;
        vm.warp(t);

        vm.startPrank(platform);

        vm.expectEmit(true, true, false, true);
        emit VaultSiteCreated(
            "VSZH0001",
            "VAULTOP-001",
            "Zurich Prime Site",
            "CH",
            3,
            50000,
            "2025-01-15",
            platform,
            t
        );

        bool ok = _createDefaultSite("VSZH0001");
        assertTrue(ok);

        vm.stopPrank();

        assertTrue(vaultSiteRegistry.vaultSiteExistsView("VSZH0001"));

        VaultSiteRegistry.VaultSite memory s = vaultSiteRegistry.getVaultSite(
            "VSZH0001"
        );
        assertEq(s.vaultSiteId, "VSZH0001");
        assertEq(s.vaultSiteName, "Zurich Prime Site");
        assertEq(s.memberGIC, "VAULTOP-001");
        assertEq(s.city, "Zurich");
        assertEq(s.country, "CH");
        assertEq(s.numberOfVaults, 3);
        assertEq(s.maximumWeightInGoldKg, 50000);
        assertEq(s.lastAuditDate, "2025-01-15");
        assertEq(s.status, "active");
        assertEq(s.createdAt, t);
        assertEq(s.createdBy, platform);

        string[] memory ids = vaultSiteRegistry.getVaultSiteIds();
        assertEq(ids.length, 1);
        assertEq(ids[0], "VSZH0001");
    }

    function test_VaultSiteExistsView_FalseBeforeCreate_TrueAfter() public {
        assertTrue(!vaultSiteRegistry.vaultSiteExistsView("VSZH0009"));

        vm.prank(platform);
        _createDefaultSite("VSZH0009");

        assertTrue(vaultSiteRegistry.vaultSiteExistsView("VSZH0009"));
    }

    // -------------------------------------------------------------------------
    // Access control
    // -------------------------------------------------------------------------

    function test_CreateVaultSite_Unauthorized_Reverts() public {
        vm.prank(outsider);
        vm.expectRevert("Not authorized: PLATFORM role required");
        vaultSiteRegistry.createVaultSite(
            "VSNOAUTH",
            "Nope",
            "VAULTOP-001",
            "Loc",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            1,
            1,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    // -------------------------------------------------------------------------
    // Input validation edge cases
    // -------------------------------------------------------------------------

    function test_CreateVaultSite_EmptyVaultSiteId_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid vault_site_id");
        vaultSiteRegistry.createVaultSite(
            "",
            "Name",
            "VAULTOP-001",
            "Loc",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            1,
            1,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_DuplicateVaultSiteId_Reverts() public {
        vm.prank(platform);
        assertTrue(_createDefaultSite("VSZH0001"));

        vm.prank(platform);
        vm.expectRevert("Vault site already exists");
        _createDefaultSite("VSZH0001");
    }

    function test_CreateVaultSite_EmptyVaultSiteName_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid vault_site_name");
        vaultSiteRegistry.createVaultSite(
            "VSX0001",
            "",
            "VAULTOP-001",
            "Loc",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            1,
            1,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_EmptyMemberGIC_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid member_gic");
        vaultSiteRegistry.createVaultSite(
            "VSX0002",
            "Name",
            "",
            "Loc",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            1,
            1,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_EmptyLocationName_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid location_name");
        vaultSiteRegistry.createVaultSite(
            "VSX0003",
            "Name",
            "VAULTOP-001",
            "",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            1,
            1,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_EmptyRegisteredAddress_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid registered_address");
        vaultSiteRegistry.createVaultSite(
            "VSX0004",
            "Name",
            "VAULTOP-001",
            "Loc",
            "",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            1,
            1,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_EmptyCity_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid city");
        vaultSiteRegistry.createVaultSite(
            "VSX0005",
            "Name",
            "VAULTOP-001",
            "Loc",
            "RegAddr",
            "OpAddr",
            "",
            "",
            "",
            "CH",
            "",
            "",
            1,
            1,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_InvalidCountryCodeLen_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid country code");
        vaultSiteRegistry.createVaultSite(
            "VSX0006",
            "Name",
            "VAULTOP-001",
            "Loc",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CHE",
            "",
            "",
            1,
            1,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_NumberOfVaultsZero_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("number_of_vaults must be > 0");
        vaultSiteRegistry.createVaultSite(
            "VSX0007",
            "Name",
            "VAULTOP-001",
            "Loc",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            0,
            1,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_MaxWeightZero_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("maximum_weight_in_gold_kg must be > 0");
        vaultSiteRegistry.createVaultSite(
            "VSX0008",
            "Name",
            "VAULTOP-001",
            "Loc",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            1,
            0,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_EmptyInsurerName_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid insurer name");
        vaultSiteRegistry.createVaultSite(
            "VSX0009",
            "Name",
            "VAULTOP-001",
            "Loc",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            1,
            1,
            "",
            "",
            "2026-01-01",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_EmptyInsuranceExpiration_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid insurance expiration");
        vaultSiteRegistry.createVaultSite(
            "VSX0010",
            "Name",
            "VAULTOP-001",
            "Loc",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            1,
            1,
            "",
            "Insurer",
            "",
            "",
            "",
            "2025-01-01"
        );
    }

    function test_CreateVaultSite_EmptyLastAuditDate_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid last_audit_date");
        vaultSiteRegistry.createVaultSite(
            "VSX0011",
            "Name",
            "VAULTOP-001",
            "Loc",
            "RegAddr",
            "OpAddr",
            "City",
            "",
            "",
            "CH",
            "",
            "",
            1,
            1,
            "",
            "Insurer",
            "2026-01-01",
            "",
            "",
            ""
        );
    }

    // -------------------------------------------------------------------------
    // Member status edge case
    // -------------------------------------------------------------------------

    function test_CreateVaultSite_RevertsIfMemberNotActive() public {
        vm.prank(platform);
        memberRegistry.suspendMember("VAULTOP-001", "test");

        vm.prank(platform);
        vm.expectRevert("Member not active");
        _createDefaultSite("VSX0012");
    }

    // -------------------------------------------------------------------------
    // Read function edge cases
    // -------------------------------------------------------------------------

    function test_GetVaultSite_RevertsIfNotExists() public {
        vm.expectRevert("Vault site does not exist");
        vaultSiteRegistry.getVaultSite("VS-404");
    }

    function test_GetVaultSiteIds_Multiple() public {
        vm.prank(platform);
        assertTrue(_createDefaultSite("VS-1"));
        vm.prank(platform);
        assertTrue(_createDefaultSite("VS-2"));
        vm.prank(platform);
        assertTrue(_createDefaultSite("VS-3"));

        string[] memory ids = vaultSiteRegistry.getVaultSiteIds();
        assertEq(ids.length, 3);
        assertEq(ids[0], "VS-1");
        assertEq(ids[1], "VS-2");
        assertEq(ids[2], "VS-3");
    }
}
