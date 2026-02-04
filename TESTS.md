# Tests

**Purpose**  
Document what is tested, how to run it, and what each test verifies. This is the handoff guide for QA and reviewers.

**Scope**  
Contracts covered: `MemberRegistry`, `GoldAccountLedger`, `GoldAssetToken`, `TransactionOrderBook`, `VaultSiteRegistry`, plus a cross‑contract integration flow.

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
Test file: `test/MemberRegistry.t.sol`  
Functions exercised: `registerMember`, `setRole`, `isMemberInRole`, `suspendMember`, `registerUser`, `linkUserToMember`, `addUserAdminAddress`, `suspendUser`, `activateUser`, `validatePermission`, `getMemberDetails`, `getUserDetails`, `getMembersCount`, `getUsersCount`, `linkAddressToMember`

**GoldAccountLedger**  
Test file: `test/GoldAccountLedger.t.sol`  
Functions exercised: `createAccount`, `getAccountBalance`, `updateBalance`, `setBalanceUpdater`, `updateBalanceFromContract`, `getAccountsByMember`, `getAccountsByAddress`

**GoldAssetToken**  
Test file: `test/GoldAssetToken.t.sol`  
Functions exercised: `mint`, `getAssetDetails`, `updateStatus`, `updateCustodyBatch`, `burn`, `isAssetLocked`, `verifyCertificate`, `getAssetsByOwner`, `forceTransfer`, `safeTransferFrom`, `assetOwner`, `balanceOf`

**TransactionOrderBook**  
Test file: `test/TransactionOrderBook.t.sol`  
Functions exercised: `createOrder`, `prepareOrder`, `signOrder`, `getOrderStatus`

**VaultSiteRegistry**  
Test file: `test/VaultSiteRegistry.t.sol`  
Functions exercised: `createVaultSite`, `vaultSiteExistsView`, `getVaultSite`, `getVaultSiteIds`

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

### `test/TransactionOrderBook.t.sol`
1. `test_PrepareSignFlow` - register (prepare) order then counterparty signs.
2. `test_CounterpartyCannotSignBeforePrepare` - cannot sign before prepare.

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

### `test/IntegrationFlow.t.sol`
1. `test_EndToEnd_Flow` - full lifecycle: member setup, account creation, mint, prepare, custody in transit, sign, execute, and verify ownership + ledger balances.

## Integration Flow Summary
1. GMO members created and roles set.
2. Sender/receiver IGAN accounts created.
3. Asset minted to sender.
4. Order registered via `prepareOrder` with tokenIds + seller signature.
5. LSP sets custody batch to `IN_TRANSIT`.
6. Counterparty signs, then execute order and confirm asset transfer + ledger updates.

## Common Failure Causes
1. Missing role setup (GMO/REFINER/MINTER/TRADER).
2. Counterparty tries to sign before prepare.
3. Balance updater not allowlisted.
4. Empty or invalid IDs (GIC, IGAN, tokenIds).

## Notes
1. Tests use deterministic IDs and addresses for repeatability.
2. Revert reasons are asserted for access control and validation.
