// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/VaultRegistry.sol";

/// @dev Minimal mock that satisfies what VaultRegistry uses:
///      vaultSiteExistsView(vaultSiteId) -> bool
contract MockVaultSiteRegistry {
    mapping(string => bool) private _exists;

    function setExists(string memory vaultSiteId, bool exists) external {
        _exists[vaultSiteId] = exists;
    }

    function vaultSiteExistsView(string memory vaultSiteId) external view returns (bool) {
        return _exists[vaultSiteId];
    }
}

contract VaultRegistryTest is Test {
    MemberRegistry public memberRegistry;
    MockVaultSiteRegistry public vaultSiteRegistry;
    VaultRegistry public vaultRegistry;

    address platform = address(0x1);
    address vaultOp  = address(0x2);
    address outsider = address(0x3);

    uint256 constant ROLE_VAULT_OP = 1 << 3;

    // Events copied exactly from VaultRegistry (so expectEmit works)
    event VaultCreated(
        string indexed vaultId,
        string indexed vaultSiteId,
        string memberInternalVaultId,
        string vaultDimensions,
        uint256 vaultGoldCapacityKg,
        VaultRegistry.VaultStatus vaultStatus,
        address indexed createdBy,
        uint256 timestamp
    );

    event VaultStatusUpdated(
        string indexed vaultId,
        string indexed vaultSiteId,
        VaultRegistry.VaultStatus previousStatus,
        VaultRegistry.VaultStatus newStatus,
        string reason,
        string lastAuditDate,
        address indexed updatedBy,
        uint256 timestamp
    );

    function setUp() public {
        memberRegistry = new MemberRegistry();

        // Make `platform` act as PLATFORM (linkAddressToMember can be called by owner == address(this))
        memberRegistry.linkAddressToMember(platform, "PLATFORM");

        // Register a VAULT_OP member so vaultOp has ROLE_VAULT_OP
        vm.prank(platform);
        memberRegistry.registerMember(
            "VAULTOP-001",
            MemberRegistry.MemberType.COMPANY,
            keccak256("vaultop-001"),
            vaultOp,
            ROLE_VAULT_OP
        );

        vaultSiteRegistry = new MockVaultSiteRegistry();

        // Create one valid vault site for tests
        vaultSiteRegistry.setExists("VSZH0001", true);

        vaultRegistry = new VaultRegistry(address(memberRegistry), address(vaultSiteRegistry));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    function _createVaultAs(address caller, string memory siteId, string memory vaultId) internal returns (bool) {
        vm.prank(caller);
        return vaultRegistry.createVault(
            siteId,
            vaultId,
            "ZH-VAULT-A1",
            "40-50-60",
            1000, // kg
            VaultRegistry.VaultStatus.UNUSED,
            "2025-01-15"
        );
    }

    function _createDefaultVault() internal returns (string memory) {
        string memory vaultId = "VZH001A";
        bool ok = _createVaultAs(platform, "VSZH0001", vaultId);
        assertTrue(ok);
        return vaultId;
    }

    // -------------------------------------------------------------------------
    // Normal cases
    // -------------------------------------------------------------------------

    function test_CreateVault_AsPlatform_Succeeds() public {
        uint256 t = 111;
        vm.warp(t);

        vm.expectEmit(true, true, false, true);
        emit VaultCreated(
            "VZH001A",
            "VSZH0001",
            "ZH-VAULT-A1",
            "40-50-60",
            1000,
            VaultRegistry.VaultStatus.UNUSED,
            platform,
            t
        );

        bool ok = _createVaultAs(platform, "VSZH0001", "VZH001A");
        assertTrue(ok);

        assertTrue(vaultRegistry.vaultExistsView("VZH001A"));

        VaultRegistry.Vault memory v = vaultRegistry.getVault("VZH001A");
        assertEq(v.vaultId, "VZH001A");
        assertEq(v.vaultSiteId, "VSZH0001");
        assertEq(v.memberInternalVaultId, "ZH-VAULT-A1");
        assertEq(v.vaultDimensions, "40-50-60");
        assertEq(v.vaultGoldCapacityKg, 1000);
        assertEq(uint8(v.status), uint8(VaultRegistry.VaultStatus.UNUSED));
        assertEq(v.lastAuditDate, "2025-01-15");
        assertEq(v.outOfServiceReason, "");
        assertEq(v.createdAt, t);
        assertEq(v.createdBy, platform);

        string[] memory bySite = vaultRegistry.getVaultIdsBySite("VSZH0001");
        assertEq(bySite.length, 1);
        assertEq(bySite[0], "VZH001A");

        string[] memory all = vaultRegistry.getAllVaultIds();
        assertEq(all.length, 1);
        assertEq(all[0], "VZH001A");
    }

    function test_CreateVault_AsVaultOp_Succeeds() public {
        bool ok = _createVaultAs(vaultOp, "VSZH0001", "VZH002B");
        assertTrue(ok);
        assertTrue(vaultRegistry.vaultExistsView("VZH002B"));
    }

    // -------------------------------------------------------------------------
    // Access control
    // -------------------------------------------------------------------------

    function test_CreateVault_Unauthorized_Reverts() public {
        vm.prank(outsider);
        vm.expectRevert("Not authorized");
        vaultRegistry.createVault(
            "VSZH0001",
            "VNOAUTH",
            "INT",
            "10-10-10",
            1,
            VaultRegistry.VaultStatus.UNUSED,
            ""
        );
    }

    function test_UpdateVaultStatus_Unauthorized_Reverts() public {
        string memory vaultId = _createDefaultVault();

        vm.prank(outsider);
        vm.expectRevert("Not authorized");
        vaultRegistry.updateVaultStatus(
            vaultId,
            VaultRegistry.VaultStatus.OUT_OF_SERVICE,
            "nope",
            "2025-02-01"
        );
    }

    // -------------------------------------------------------------------------
    // Input validation (createVault)
    // -------------------------------------------------------------------------

    function test_CreateVault_EmptyVaultSiteId_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid vault_site_id");
        vaultRegistry.createVault(
            "",
            "V1",
            "INT",
            "10-10-10",
            1,
            VaultRegistry.VaultStatus.UNUSED,
            ""
        );
    }

    function test_CreateVault_NonexistentVaultSite_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Vault site does not exist");
        vaultRegistry.createVault(
            "VS-NO",
            "V1",
            "INT",
            "10-10-10",
            1,
            VaultRegistry.VaultStatus.UNUSED,
            ""
        );
    }

    function test_CreateVault_EmptyVaultId_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid vault_id");
        vaultRegistry.createVault(
            "VSZH0001",
            "",
            "INT",
            "10-10-10",
            1,
            VaultRegistry.VaultStatus.UNUSED,
            ""
        );
    }

    function test_CreateVault_DuplicateVaultId_Reverts() public {
        _createDefaultVault();

        vm.prank(platform);
        vm.expectRevert("Vault already exists");
        vaultRegistry.createVault(
            "VSZH0001",
            "VZH001A",
            "INT2",
            "20-20-20",
            2,
            VaultRegistry.VaultStatus.USED,
            ""
        );
    }

    function test_CreateVault_EmptyInternalId_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid internal id");
        vaultRegistry.createVault(
            "VSZH0001",
            "V3",
            "",
            "10-10-10",
            1,
            VaultRegistry.VaultStatus.UNUSED,
            ""
        );
    }

    function test_CreateVault_EmptyDimensions_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid dimensions");
        vaultRegistry.createVault(
            "VSZH0001",
            "V4",
            "INT",
            "",
            1,
            VaultRegistry.VaultStatus.UNUSED,
            ""
        );
    }

    function test_CreateVault_ZeroCapacity_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Invalid capacity");
        vaultRegistry.createVault(
            "VSZH0001",
            "V5",
            "INT",
            "10-10-10",
            0,
            VaultRegistry.VaultStatus.UNUSED,
            ""
        );
    }

    // -------------------------------------------------------------------------
    // Status update behavior
    // -------------------------------------------------------------------------

    function test_UpdateVaultStatus_ToOutOfService_SetsReason_UpdatesAudit_Emits() public {
        string memory vaultId = _createDefaultVault();

        uint256 t = 222;
        vm.warp(t);

        // before is UNUSED (from helper)
        vm.expectEmit(true, true, false, true);
        emit VaultStatusUpdated(
            vaultId,
            "VSZH0001",
            VaultRegistry.VaultStatus.UNUSED,
            VaultRegistry.VaultStatus.OUT_OF_SERVICE,
            "maintenance",
            "2025-02-01",
            platform,
            t
        );

        vm.prank(platform);
        bool ok = vaultRegistry.updateVaultStatus(
            vaultId,
            VaultRegistry.VaultStatus.OUT_OF_SERVICE,
            "maintenance",
            "2025-02-01"
        );
        assertTrue(ok);

        VaultRegistry.Vault memory v = vaultRegistry.getVault(vaultId);
        assertEq(uint8(v.status), uint8(VaultRegistry.VaultStatus.OUT_OF_SERVICE));
        assertEq(v.outOfServiceReason, "maintenance");
        assertEq(v.lastAuditDate, "2025-02-01");
    }

    function test_UpdateVaultStatus_ToUsed_ClearsReasonWhenEmpty_DoesNotOverwriteAuditWhenEmpty() public {
        string memory vaultId = _createDefaultVault();

        // First: set OUT_OF_SERVICE with reason and audit date
        vm.prank(platform);
        vaultRegistry.updateVaultStatus(
            vaultId,
            VaultRegistry.VaultStatus.OUT_OF_SERVICE,
            "broken lock",
            "2025-02-01"
        );

        // Now: set USED with empty reason and empty audit date -> should clear reason, keep audit
        vm.prank(platform);
        bool ok = vaultRegistry.updateVaultStatus(
            vaultId,
            VaultRegistry.VaultStatus.USED,
            "",
            ""
        );
        assertTrue(ok);

        VaultRegistry.Vault memory v = vaultRegistry.getVault(vaultId);
        assertEq(uint8(v.status), uint8(VaultRegistry.VaultStatus.USED));
        assertEq(v.outOfServiceReason, "");          // cleared
        assertEq(v.lastAuditDate, "2025-02-01");      // unchanged
    }

    function test_UpdateVaultStatus_NonexistentVault_Reverts() public {
        vm.prank(platform);
        vm.expectRevert("Vault does not exist");
        vaultRegistry.updateVaultStatus(
            "V-404",
            VaultRegistry.VaultStatus.USED,
            "x",
            "2025-01-01"
        );
    }

    // -------------------------------------------------------------------------
    // Listing + existence
    // -------------------------------------------------------------------------

    function test_GetVaultIdsBySite_Multiple() public {
        assertTrue(_createVaultAs(platform, "VSZH0001", "V1"));
        assertTrue(_createVaultAs(platform, "VSZH0001", "V2"));
        assertTrue(_createVaultAs(platform, "VSZH0001", "V3"));

        string[] memory ids = vaultRegistry.getVaultIdsBySite("VSZH0001");
        assertEq(ids.length, 3);
        assertEq(ids[0], "V1");
        assertEq(ids[1], "V2");
        assertEq(ids[2], "V3");
    }

    function test_GetAllVaultIds_Multiple() public {
        assertTrue(_createVaultAs(platform, "VSZH0001", "V1"));
        assertTrue(_createVaultAs(platform, "VSZH0001", "V2"));

        string[] memory all = vaultRegistry.getAllVaultIds();
        assertEq(all.length, 2);
        assertEq(all[0], "V1");
        assertEq(all[1], "V2");
    }

    function test_VaultExistsView() public {
        assertTrue(!vaultRegistry.vaultExistsView("NOPE"));
        _createDefaultVault();
        assertTrue(vaultRegistry.vaultExistsView("VZH001A"));
    }

    function test_GetVault_RevertsIfNotExists() public {
        vm.expectRevert("Vault does not exist");
        vaultRegistry.getVault("NOPE");
    }
}
