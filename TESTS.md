# Test Audit Report

Made by Rayen Harhouri.

**Audit Objective**  
Provide a clear, review‑ready audit of unit test coverage and quality for the smart contracts. This document is the source of truth for QA and reviewers.

**Audit Date**  
2026-02-20

**Scope**  
Contracts covered: `MemberRegistry`, `GoldAccountLedger`, `GoldAssetToken`, `TransactionOrderBook`, `DocumentRegistry`, `VaultSiteRegistry`, `VaultRegistry`, plus a cross‑contract integration flow.

**Audit Summary**  
Status: Closed for current US-11 scope, with one tooling limitation on `forge coverage`.  
Strengths:
- Transaction lifecycle tests cover prepare → sign → execute.
- Asset custody and status transitions are tested, including reentrancy safety on ERC1155 receiver.
- Document anchoring is fully unit‑tested (single, batch, sets, verification).
Closed gaps in this update:
- `MemberRegistry`: added coverage for blacklist management, member approval/termination, status getters, and `getMyRoles`.
- `GoldAccountLedger`: added coverage for `getAccountDetails` success/revert paths.
- `GoldAssetToken`: added coverage for `transferAsset`, blacklist admin gates, warrant getters, `uri`, `getAssetStatus`, and owner setters.
- `TransactionOrderBook`: added coverage for owner setters, status update paths, cancel/fail, and getter coverage (`getOrderDetails`, `getOrderSignatures`).
Resolved in this update:
- `VaultSiteRegistry.createVaultSite` now validates `lastAuditDate`; full suite is green (`142/142`).

**Audit Evidence (Latest Runs)**  
- `forge test --match-path test/TransactionOrderBookAdditional.t.sol` → 10/10 passed.
- `forge test --match-path test/MemberRegistryAdditional.t.sol` → 9/9 passed.
- `forge test --match-path test/GoldAccountLedgerAdditional.t.sol` → 2/2 passed.
- `forge test --match-path test/GoldAssetTokenAdditional.t.sol` → 9/9 passed.
- `forge test --summary` → 142/142 passed overall (100.00% pass rate).
- `forge snapshot` → `.gas-snapshot` baseline generated with full suite (no exclusions).
- `forge snapshot --check` → baseline check passed.
- Detailed gas charts and hotspot breakdown: `GAS_SNAPSHOT_REPORT.md`.
- Slither run via Docker:
  - `docker run --rm -v "$PWD":/share -w /share trailofbits/eth-security-toolbox slither . --filter-paths "lib|test|script|out|cache" --json /share/slither-report.json`
  - Result counts: `0 high`, `13 medium`, `66 low`, `14 informational`, `6 optimization` (`99` total detectors).
- `forge coverage --ir-minimum` remains blocked by Yul stack-depth exception in `TransactionOrderBook.prepareOrder` (after refactor attempt to struct-based `_createOrder` input).

## US-11 Quality Dashboard

### Gate Status (US-11)
| Quality Gate | Status | Evidence | Note |
|---|---|---|---|
| `>= 80%` code coverage | `BLOCKED (tooling)` | `forge coverage --ir-minimum` | Coverage run fails with Yul stack-depth exception in `prepareOrder`; function-level audit (`89/89`) is used as evidence. |
| Reentrancy attack tests | `PASS` | `test/GoldAssetToken.t.sol:test_Reentrancy_SafeTransfer_DoesNotCorruptAssetOwner` | Reentrancy path covered and passing. |
| Role / whitelist permission tests | `PASS` | Member, token blacklist, ledger updater, order permissions tests | Access-control suites are passing. |
| Slither no critical/high findings | `PASS` | `slither-report.json` | No high/critical findings reported by Slither. Medium findings are tracked for hardening. |
| Gas snapshot baseline committed | `PASS` | `.gas-snapshot`, `forge snapshot --check` | Baseline generated from full passing suite (no exclusions). |

### Function Coverage Chart (Audited Contract Surface)
Coverage here reflects explicit public/external functions defined in each contract and mapped to tests in this file.

| Contract | Covered | Coverage |
|---|---:|---:|
| `MemberRegistry` | `24/24` | `100%` |
| `GoldAccountLedger` | `8/8` | `100%` |
| `GoldAssetToken` | `19/19` | `100%` |
| `TransactionOrderBook` | `15/15` | `100%`* |
| `DocumentRegistry` | `13/13` | `100%` |
| `VaultSiteRegistry` | `4/4` | `100%` |
| `VaultRegistry` | `6/6` | `100%` |
| **Total** | **`89/89`** | **`100%`** |

`*` `executeOrder` coverage is provided through `test/IntegrationFlow.t.sol`.

### Test Pass Chart (Current Full Run)
| Metric | Value |
|---|---:|
| Total tests | `142` |
| Passing | `142` |
| Failing | `0` |
| Pass rate | `100.00%` |

```
Pass Rate  [####################] 100.00%
Coverage   [####################] 100.00% (audited function surface)
```

**Prerequisites**  
1. Foundry installed and `forge` available.
2. Run commands from repo root.

**How To Run**  
1. Full suite: `forge test`  
2. Single file: `forge test --match-path test/GoldAssetToken.t.sol`  
3. Integration flow only: `forge test --match-path test/IntegrationFlow.t.sol`  
4. Verbose debugging: `forge test -vvv`

**Expected Output**  
All tests pass. Revert reasons are asserted explicitly in many cases. If a test fails, use `-vvv` to view the revert reason and call stack.

## Coverage Map (Contract -> Tests -> Functions)

**MemberRegistry**  
Test files: `test/MemberRegistry.t.sol`, `test/MemberRegistryAdditional.t.sol`  
Functions exercised: `registerMember`, `setRole`, `isMemberInRole`, `suspendMember`, `registerUser`, `linkUserToMember`, `addUserAdminAddress`, `suspendUser`, `activateUser`, `validatePermission`, `getMemberDetails`, `getUserDetails`, `getMembersCount`, `getUsersCount`, `linkAddressToMember`, `isBlacklisted`, `addToBlacklist`, `removeFromBlacklist`, `setBlacklisted`, `approveMember`, `terminateMember`, `getMemberStatus`, `getUserStatus`, `getMyRoles`

**GoldAccountLedger**  
Test files: `test/GoldAccountLedger.t.sol`, `test/GoldAccountLedgerAdditional.t.sol`  
Functions exercised: `createAccount`, `getAccountBalance`, `updateBalance`, `setBalanceUpdater`, `updateBalanceFromContract`, `getAccountsByMember`, `getAccountsByAddress`, `getAccountDetails`

**GoldAssetToken**  
Test files: `test/GoldAssetToken.t.sol`, `test/GoldAssetTokenAdditional.t.sol`  
Functions exercised: `mint`, `getAssetDetails`, `updateStatus`, `updateCustody`, `updateCustodyBatch`, `burn`, `isAssetLocked`, `verifyCertificate`, `getAssetsByOwner`, `forceTransfer`, `safeTransferFrom`, `assetOwner`, `balanceOf`, `transferAsset`, `addToBlacklist`, `removeFromBlacklist`, `isWarrantUsed`, `getTokenByWarrant`, `uri`, `setMemberRegistry`, `setAccountLedger`, `getAssetStatus`

**TransactionOrderBook**  
Test files: `test/TransactionOrderBook.t.sol`, `test/TransactionOrderBookAdditional.t.sol`  
Functions exercised: `setMemberRegistry`, `setGoldAccountLedger`, `setGoldAssetToken`, `setMinSignatures`, `setExecutionOptions`, `createOrder`, `prepareOrder`, `signOrder`, `executeOrder`, `cancelOrder`, `failOrder`, `updateOrderStatus`, `getOrderDetails`, `getOrderStatus`, `getOrderSignatures`

**DocumentRegistry**  
Test file: `test/DocumentRegistry.t.sol`  
Functions exercised: `registerDocument`, `uploadDocument`, `registerDocumentSet`, `uploadDocumentBatch`, `verifyDocument`, `verifyDocumentAndLog`, `verifyDocumentSet`, `getDocumentDetails`, `getDocumentHash`, `getDocumentSetDetails`, `getDocumentSetRootHash`, `supersedeDocument`, `revokeDocument`

**VaultSiteRegistry**  
Test file: `test/VaultSiteRegistry.t.sol`  
Functions exercised: `createVaultSite`, `vaultSiteExistsView`, `getVaultSite`, `getVaultSiteIds`

**VaultRegistry**  
Test file: `test/VaultRegistry.t.sol`  
Functions exercised: `createVault`, `updateVaultStatus`, `getVault`, `getVaultIdsBySite`, `getAllVaultIds`, `vaultExistsView`

**Cross‑contract Integration**  
Test file: `test/IntegrationFlow.t.sol`  
Functions exercised: `setGoldAccountLedger`, `setGoldAssetToken`, `setExecutionOptions`, `setBalanceUpdater`, `createAccount`, `mint`, `setApprovalForAll`, `prepareOrder`, `signOrder`, `executeOrder`, `assetOwner`, `getAccountBalance`, `updateCustodyBatch`, `getAssetStatus`

## Test Inventory (Detailed)

### `test/MemberRegistry.t.sol`
1. `test_RegisterMember` - registers a member and validates stored fields.
2. `test_SetRole_Grant` - GMO assigns a role and the role bit is set.
3. `test_IsMemberInRole` - checks role membership via `isMemberInRole`.
4. `test_SetRole_Revoke` - GMO revokes a role and the bit is cleared.
5. `test_SuspendMember` - suspends a member and validates status.
6. `test_RegisterUser` - registers a user and validates stored fields.
7. `test_LinkUserToMember` - links user to member and validates linkage.
8. `test_AddUserAdminAddress` - adds admin address to user.
9. `test_SuspendUser` - suspends a user and validates status.
10. `test_ActivateUser` - reactivates a suspended user.
11. `test_ValidatePermission` - validates role‑based permissions.
12. `test_OnlyGmoCanSetRole` - non‑GMO cannot assign roles.
13. `test_GetMembersCount` - count includes platform member.
14. `test_GetUsersCount` - validates total registered users.

### `test/MemberRegistryAdditional.t.sol`
1. `test_Blacklist_Add_Remove_Set_And_IsBlacklisted` - full blacklist lifecycle.
2. `test_Blacklist_Functions_OnlyGmo` - blacklist admin access control.
3. `test_ApproveMember_Reverts_WhenNotPending` - approval guard validation.
4. `test_ApproveMember_Succeeds_WhenPending` - pending -> active transition.
5. `test_TerminateMember_SetsStatus` - termination status update.
6. `test_GetMemberStatus_ReturnsCurrentStatus` - member status getter.
7. `test_GetUserStatus_ReturnsCurrentStatus` - user status getter.
8. `test_GetMyRoles_ReturnsRolesForActiveMember` - active role retrieval.
9. `test_GetMyRoles_ReturnsZero_IfMemberNotActive` - inactive role masking.

### `test/GoldAccountLedger.t.sol`
1. `testCreateAccount` - creates account and confirms balance.
2. `testCreateAccount_IncrementsIGAN` - multiple accounts for same member.
3. `testCreateAccount_RevertsIfMemberNotActive` - suspended member cannot create.
4. `testUnauthorizedCannotCreateAccount` - non‑creator cannot create.
5. `testUpdateBalance_ByPlatform` - GMO updates balance successfully.
6. `testCustodianCanUpdateBalance` - VAULT can update balance.
7. `testUpdateBalance_RevertsIfNotAuthorized` - unauthorized update rejected.
8. `testUpdateBalance_NegativeDelta_RevertsIfInsufficient` - overdraft rejected.
9. `testGetAccountBalance_RevertsIfAccountDoesNotExist` - invalid IGAN rejected.
10. `testUpdateBalance_RevertsIfAccountDoesNotExist` - invalid IGAN rejected.
11. `testSetBalanceUpdater_OnlyPlatform` - only GMO can allow updater.
12. `testUpdateBalanceFromContract_RevertsIfNotUpdater` - allowlist enforced.
13. `testUpdateBalanceFromContract_WorksWhenUpdaterAllowed` - allowlist works.
14. `testGetAccountsByMember` - member accounts list.
15. `testGetAccountsByAddress` - address accounts list.
16. `test_Event_AccountCreated` - event emitted on create.
17. `test_Event_BalanceUpdated_Platform` - event emitted for positive delta.
18. `test_Event_BalanceUpdated_NegativeDelta` - event emitted for negative delta.
19. `test_Event_BalanceUpdaterSet` - event emitted on allowlist change.
20. `test_Event_BalanceUpdated_FromContractUpdater` - event emitted via updater.

### `test/GoldAccountLedgerAdditional.t.sol`
1. `test_GetAccountDetails_ReturnsCreatedAccount` - account details success path.
2. `test_GetAccountDetails_Reverts_WhenAccountMissing` - missing-account guard.

### `test/GoldAssetToken.t.sol`
1. `test_MintGoldAsset` - minting sets asset fields and updates ledger.
2. `test_DuplicateSerialAllowed` - serial duplication allowed.
3. `test_OnlyRefinerOrMinterCanMint` - access control enforced.
4. `test_UpdateStatus` - owner updates asset status.
5. `test_BurnAsset_UpdatesLedgerWithStoredIgan` - burn uses stored IGAN.
6. `test_IsAssetLocked` - lock derived from status.
7. `test_VerifyCertificate` - certificate hash validation.
8. `test_GetAssetsByOwner` - owner asset list.
9. `test_FineWeightCalculation` - fineness math.
10. `test_WarrantDuplicatePrevention` - warrant uniqueness enforced.
11. `test_ForceTransfer` - admin can force transfer.
12. `test_Transfer_UpdatesAssetOwner_AndEmitsOwnershipUpdated` - transfer updates.
13. `test_Transfer_Reverts_WhenEitherSideBlacklisted` - blacklist enforced.
14. `test_Transfer_Reverts_WhenAssetLocked_Pledged` - lock blocks transfer.
15. `test_Transfer_Reverts_WhenAssetLocked_InTransit` - lock blocks transfer.
16. `test_OldOwnerCannotBurnOrUpdateStatusAfterTransfer` - old owner blocked.
17. `test_ForceTransfer_BypassesWhitelist` - force transfer still allowed.
18. `test_ForceTransfer_Reverts_WhenAssetLocked_WithCurrentUpdateLogic` - lock blocks.
19. `test_VerifyCertificate_NonExistentToken_Reverts` - invalid token rejected.
20. `test_Burn_NonExistentToken_Reverts` - invalid token rejected.
21. `test_UpdateCustodyBatch_SetsInTransit` - batch custody updates set status to in transit.
22. `test_Reentrancy_SafeTransfer_DoesNotCorruptAssetOwner` - reentrancy safety on ERC1155 receiver hook.
23. `test_UpdateCustody_SetsInTransit` - single custody update sets status to in transit.
24. `test_UpdateCustody_Reverts_WhenUnauthorized` - custody update blocked for non-operators.

### `test/GoldAssetTokenAdditional.t.sol`
1. `test_TransferAsset_Works_ForTokenOwner` - owner transfer path.
2. `test_TransferAsset_Reverts_WhenNotTokenOwner` - ownership guard.
3. `test_TransferAsset_Reverts_WhenRecipientBlacklisted` - blacklist transfer guard.
4. `test_AddRemoveBlacklist_OnlyGmo` - GMO-only admin wrappers.
5. `test_IsWarrantUsed_And_GetTokenByWarrant` - warrant query functions.
6. `test_Uri_ReturnsIpfsPath` - metadata URI formatting.
7. `test_GetAssetStatus_ReturnsRegisteredAfterMint` - status getter validation.
8. `test_SetMemberRegistry_OnlyOwner_And_Validation` - owner setter + zero-address guard.
9. `test_SetAccountLedger_OnlyOwner` - owner-only setter.

### `test/TransactionOrderBook.t.sol`
1. `test_PrepareSignFlow` - register (prepare) order then counterparty signs.
2. `test_CounterpartyCannotSignBeforePrepare` - cannot sign before prepare.

### `test/TransactionOrderBookAdditional.t.sol`
1. `test_SetMemberRegistry_OnlyOwner_And_Updates` - registry setter + owner gate.
2. `test_SetGoldAccountLedger_OnlyOwner` - ledger setter + owner gate.
3. `test_SetGoldAssetToken_OnlyOwner` - token setter + owner gate.
4. `test_SetMinSignatures_OnlyOwner_And_ValueGuard` - min-signature constraints.
5. `test_SetExecutionOptions_OnlyOwner` - execution options setter.
6. `test_CancelOrder_SetsStatus` - cancel transition.
7. `test_FailOrder_SetsStatus` - fail transition.
8. `test_UpdateOrderStatus_Executed_SetsExecutedAt` - execution status path.
9. `test_UpdateOrderStatus_InvalidTransition_Reverts` - invalid status transition guard.
10. `test_GetOrderDetails_And_GetOrderSignatures` - read APIs coverage.

### `test/DocumentRegistry.t.sol`
1. `test_RegisterDocument_Succeeds_And_Getters` - register + get details/hash.
2. `test_RegisterDocument_Unauthorized_Reverts` - upload role enforced.
3. `test_UploadDocument_Succeeds` - upload alias works.
4. `test_RegisterDocumentSet_Succeeds` - set registration and getters.
5. `test_RegisterDocumentSet_Reverts_WhenDocMissing` - missing doc blocked.
6. `test_RegisterDocumentSet_Reverts_WhenDocAlreadyInSet` - doc uniqueness in sets.
7. `test_UploadDocumentBatch_Succeeds` - batch upload + set creation.
8. `test_UploadDocumentBatch_Reverts_OnLengthMismatch` - array size validation.
9. `test_VerifyDocument_True_False` - verification true/false cases.
10. `test_VerifyDocumentAndLog_Emits` - emits audit event.
11. `test_VerifyDocumentSet_SingleLeaf` - merkle proof path.
12. `test_SupersedeDocument_And_Revoke` - status changes and verification.
13. `test_GetDocumentDetails_Reverts_WhenMissing` - missing doc guard.
14. `test_GetDocumentSetDetails_Reverts_WhenMissing` - missing set guard.

### `test/VaultSiteRegistry.t.sol`
1. `test_CreateVaultSite_AsPlatform_Succeeds` - platform creation and stored fields.
2. `test_VaultSiteExistsView_FalseBeforeCreate_TrueAfter` - existence check.
3. `test_CreateVaultSite_Unauthorized_Reverts` - access control.
4. `test_CreateVaultSite_EmptyVaultSiteId_Reverts` - input validation.
5. `test_CreateVaultSite_DuplicateVaultSiteId_Reverts` - uniqueness.
6. `test_CreateVaultSite_EmptyVaultSiteName_Reverts` - input validation.
7. `test_CreateVaultSite_EmptyMemberGIC_Reverts` - input validation.
8. `test_CreateVaultSite_EmptyLocationName_Reverts` - input validation.
9. `test_CreateVaultSite_EmptyRegisteredAddress_Reverts` - input validation.
10. `test_CreateVaultSite_EmptyCity_Reverts` - input validation.
11. `test_CreateVaultSite_InvalidCountryCodeLen_Reverts` - input validation.
12. `test_CreateVaultSite_NumberOfVaultsZero_Reverts` - input validation.
13. `test_CreateVaultSite_MaxWeightZero_Reverts` - input validation.
14. `test_CreateVaultSite_EmptyInsurerName_Reverts` - input validation.
15. `test_CreateVaultSite_EmptyInsuranceExpiration_Reverts` - input validation.
16. `test_CreateVaultSite_EmptyLastAuditDate_Reverts` - input validation.
17. `test_CreateVaultSite_RevertsIfMemberNotActive` - member status enforced.
18. `test_GetVaultSite_RevertsIfNotExists` - read path validation.
19. `test_GetVaultSiteIds_Multiple` - list ordering and count.

### `test/VaultRegistry.t.sol`
1. `test_CreateVault_AsPlatform_Succeeds` - platform creation and stored fields.
2. `test_CreateVault_AsVaultOp_Succeeds` - vault operator creation.
3. `test_CreateVault_Unauthorized_Reverts` - access control.
4. `test_UpdateVaultStatus_Unauthorized_Reverts` - access control.
5. `test_CreateVault_EmptyVaultSiteId_Reverts` - input validation.
6. `test_CreateVault_NonexistentVaultSite_Reverts` - site must exist.
7. `test_CreateVault_EmptyVaultId_Reverts` - input validation.
8. `test_CreateVault_DuplicateVaultId_Reverts` - uniqueness.
9. `test_CreateVault_EmptyInternalId_Reverts` - input validation.
10. `test_CreateVault_EmptyDimensions_Reverts` - input validation.
11. `test_CreateVault_ZeroCapacity_Reverts` - input validation.
12. `test_UpdateVaultStatus_ToOutOfService_SetsReason_UpdatesAudit_Emits` - status change behavior.
13. `test_UpdateVaultStatus_ToUsed_ClearsReasonWhenEmpty_DoesNotOverwriteAuditWhenEmpty` - status change behavior.
14. `test_UpdateVaultStatus_NonexistentVault_Reverts` - missing vault guard.
15. `test_GetVaultIdsBySite_Multiple` - listing by site.
16. `test_GetAllVaultIds_Multiple` - listing all vaults.
17. `test_VaultExistsView` - existence view.
18. `test_GetVault_RevertsIfNotExists` - missing vault guard.

### `test/IntegrationFlow.t.sol`
1. `test_EndToEnd_Flow` - full lifecycle: member setup, account creation, mint, prepare, custody in transit, sign, execute, and verify ownership + ledger balances.

## Integration Flow Summary
1. GMO members created and roles set.
2. Sender/receiver IGAN accounts created.
3. Asset minted to sender.
4. Order registered via `prepareOrder` with tokenIds + seller signature.
5. LSP sets custody batch to `IN_TRANSIT`.
6. Counterparty signs, then execute order and confirm asset transfer + ledger updates.

## US-19 On-Chain Coverage
1. LSP custody updates set assets to `IN_TRANSIT` via `updateCustody` and `updateCustodyBatch`.
2. Transfers are blocked while assets are `IN_TRANSIT`.
3. Execution moves assets from `IN_TRANSIT` to `IN_VAULT` and then transfers ownership.

## US-19 Backend Plan (Stubs + Tests To Implement)
This repo does not include backend code, so the items below are a plan and stub list to implement in the API gateway/service.

**Mock Logistics Partner Stubs**
1. `POST /partner/pickup` with `{ transaction_reference, token_ids, custody_party_id, custody_type }`
2. `POST /partner/delivery` with `{ transaction_reference, token_ids, delivered_at }`
3. `GET /partner/status/{transaction_reference}`

**API Bridge Mapping Tests**
1. Pickup event triggers `PUT /assets/{token_id}/custody` or batch custody update, and asset status becomes `IN_TRANSIT`.
2. Delivery event triggers `POST /transactions/{reference}/sign` with `signing_role=counterparty`.
3. Execution path triggers `PUT /transactions/{reference}/status` with `executed` or `POST /assets/transfer` based on the chosen backend flow.

**Reconciliation Report Tests**
1. Compare partner events vs on-chain events (`CustodyChanged`, `AssetStatusChanged`, `OrderSigned`, `OrderExecuted`) for the same `transaction_reference`.
2. Generate a report with missing or out-of-order events flagged.

**Timeout/Error Handling Tests**
1. Partner timeout on pickup or delivery → retry with exponential backoff and log failure.
2. Partner timeout beyond max retries → mark transaction in reconciliation report as `partner_timeout`.

## Common Failure Causes
1. Missing role setup (GMO/REFINER/MINTER/TRADER).
2. Counterparty tries to sign before prepare.
3. Balance updater not allowlisted.
4. Empty or invalid IDs (GIC, IGAN, tokenIds).

## Notes
1. Tests use deterministic IDs and addresses for repeatability.
2. Revert reasons are asserted for access control and validation.
