# Deployment Checklist - Avalanche

## Pre-Deployment ✓

- [ ] Foundry installed and updated
- [ ] Contracts compile without errors: `forge build`
- [ ] All tests pass: `forge test`
- [ ] Private key ready (without 0x prefix)
- [ ] RPC URL tested: `cast block-number --rpc-url <RPC_URL>`
- [ ] Deployer wallet has AVAX for gas (~1 AVAX)
- [ ] `.env` file created with correct values
- [ ] `.env` file added to `.gitignore`

---

## Deployment ✓

### Command
```bash
source .env
forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Expected Output
```
MemberRegistry deployed at: 0x...
GoldAssetToken deployed at: 0x...

=== DEPLOYMENT COMPLETE ===
MemberRegistry: 0x...
GoldAssetToken: 0x...
```

- [ ] Deployment successful
- [ ] MemberRegistry address recorded
- [ ] GoldAssetToken address recorded
- [ ] Transaction hash saved

---

## Post-Deployment ✓

- [ ] Verify on SnowTrace (https://snowtrace.io)
- [ ] Check contract code matches source
- [ ] Test MemberRegistry functions
- [ ] Test GoldAssetToken functions
- [ ] Create deployment record
- [ ] Update documentation with addresses

---

## Verification ✓

### MemberRegistry
```bash
cast call <MEMBER_REGISTRY_ADDRESS> \
  "getMembersCount()" \
  --rpc-url $RPC_URL
# Expected: 0
```

### GoldAssetToken
```bash
cast call <GOLD_ASSET_TOKEN_ADDRESS> \
  "owner()" \
  --rpc-url $RPC_URL
# Expected: <DEPLOYER_ADDRESS>
```

- [ ] MemberRegistry responds to calls
- [ ] GoldAssetToken responds to calls
- [ ] Owner is correct
- [ ] No errors in responses

---

## Initialization ✓

### Link Governance
```bash
cast send <MEMBER_REGISTRY_ADDRESS> \
  "linkAddressToMember(address,string)" \
  <GOVERNANCE_ADDRESS> \
  "GOVERNANCE" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

- [ ] Governance address linked
- [ ] Transaction confirmed

### Register First Member
```bash
cast send <MEMBER_REGISTRY_ADDRESS> \
  "registerMember(string,string,string,uint8,bytes32)" \
  "GIFTCHZZ" \
  "Swiss Refinery" \
  "CH" \
  1 \
  "0x$(echo -n 'member_data' | sha256sum | cut -d' ' -f1)" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

- [ ] First member registered
- [ ] Member status is PENDING
- [ ] Transaction confirmed

### Approve Member
```bash
cast send <MEMBER_REGISTRY_ADDRESS> \
  "approveMember(string)" \
  "GIFTCHZZ" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

- [ ] Member approved
- [ ] Member status is ACTIVE
- [ ] Transaction confirmed

---

## Documentation ✓

- [ ] Deployment addresses saved
- [ ] Network configuration documented
- [ ] Gas costs recorded
- [ ] Deployment date/time noted
- [ ] Deployer address recorded
- [ ] Block number recorded

---

## Security ✓

- [ ] Private key not committed to git
- [ ] `.env` file in `.gitignore`
- [ ] No sensitive data in logs
- [ ] Contracts verified on SnowTrace
- [ ] Source code matches deployed bytecode

---

## Rollback Plan ✓

If deployment fails:
1. Check error message
2. Fix issue in code or configuration
3. Redeploy with new deployer address or network
4. Do NOT reuse same addresses

---

## Success Criteria ✓

- [ ] Both contracts deployed
- [ ] Contracts verified on SnowTrace
- [ ] All tests pass on mainnet
- [ ] Documentation updated
- [ ] Team notified
- [ ] Deployment record created

---

**Deployment Status:** Ready ✅

**Next Steps:**
1. Run deployment command
2. Verify on SnowTrace
3. Initialize system
4. Begin Phase 2 implementation
