# GIFT Blockchain - Avalanche Deployment

**Ready for Production Deployment**

---

## Quick Start

### 1. Setup Environment
```bash
cp .env.example .env
# Edit .env with your values:
# - RPC_URL: Your Avalanche RPC endpoint
# - PRIVATE_KEY: Your deployer private key
# - ETHERSCAN_API_KEY: SnowTrace API key (optional)
```

### 2. Deploy
```bash
source .env
forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### 3. Verify
```bash
forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url $RPC_URL \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Deployment Details

### Contracts to Deploy

**1. MemberRegistry**
- No constructor arguments
- Deployer automatically becomes PLATFORM admin
- ~800,000 gas

**2. GoldAssetToken**
- Constructor argument: MemberRegistry address
- Depends on MemberRegistry
- ~1,200,000 gas

### Deployment Order
```
1. Deploy MemberRegistry
   ↓
2. Deploy GoldAssetToken (pass MemberRegistry address)
```

---

## Files Created

### Configuration
- `foundry.toml` - Foundry configuration
- `.env.example` - Environment template

### Scripts
- `script/Deploy.s.sol` - Deployment script

### Documentation
- `DEPLOYMENT_GUIDE.md` - Detailed guide
- `DEPLOYMENT_CHECKLIST.md` - Step-by-step checklist
- `AVALANCHE_DEPLOYMENT.md` - This file

---

## Network Information

### Your Avalanche Network
- **RPC URL:** [Your custom RPC endpoint]
- **Chain ID:** [Your chain ID]
- **Currency:** AVAX (or your token)

### Mainnet (Reference)
- **Chain ID:** 43114
- **RPC:** https://api.avax.network/ext/bc/C/rpc
- **Explorer:** https://snowtrace.io

### Testnet (Fuji - for testing)
- **Chain ID:** 43113
- **RPC:** https://api.avax-test.network/ext/bc/C/rpc
- **Explorer:** https://testnet.snowtrace.io

---

## Deployment Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: Prepare Environment                                 │
│ ├─ Copy .env.example to .env                               │
│ ├─ Add RPC URL                                              │
│ ├─ Add Private Key                                          │
│ └─ Verify with: cast block-number --rpc-url $RPC_URL       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 2: Compile Contracts                                   │
│ ├─ Run: forge build                                         │
│ └─ Verify: No errors                                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 3: Deploy to Avalanche                                 │
│ ├─ Run deployment script                                    │
│ ├─ Confirm transaction                                      │
│ └─ Record addresses                                         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 4: Verify on SnowTrace                                 │
│ ├─ Visit SnowTrace                                          │
│ ├─ Search contract address                                  │
│ ├─ Verify source code                                       │
│ └─ Confirm deployment                                       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 5: Initialize System                                   │
│ ├─ Link governance address                                  │
│ ├─ Register first member                                    │
│ ├─ Approve member                                           │
│ └─ Assign roles                                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
                    ✅ DEPLOYMENT COMPLETE
```

---

## Gas Costs

| Operation | Gas | Cost (AVAX) |
|-----------|-----|-------------|
| MemberRegistry | 800,000 | ~0.4 |
| GoldAssetToken | 1,200,000 | ~0.6 |
| **Total** | **2,000,000** | **~1.0** |

*Costs vary based on network congestion and gas price*

---

## Post-Deployment Tasks

### 1. Record Deployment
```json
{
  "network": "avalanche",
  "timestamp": "2025-12-02T10:00:00Z",
  "memberRegistry": "0x...",
  "goldAssetToken": "0x...",
  "deployer": "0x...",
  "blockNumber": 12345678,
  "txHash": "0x..."
}
```

### 2. Initialize System
- Link governance address
- Register first member
- Approve member
- Assign roles

### 3. Update Documentation
- Add contract addresses
- Update API endpoints
- Document network details

### 4. Notify Team
- Share deployment addresses
- Provide SnowTrace links
- Update integration guides

---

## Verification Commands

### Check Deployment
```bash
# Get MemberRegistry owner
cast call <MEMBER_REGISTRY_ADDRESS> "owner()" --rpc-url $RPC_URL

# Get members count
cast call <MEMBER_REGISTRY_ADDRESS> "getMembersCount()" --rpc-url $RPC_URL

# Get GoldAssetToken owner
cast call <GOLD_ASSET_TOKEN_ADDRESS> "owner()" --rpc-url $RPC_URL
```

### Test Functionality
```bash
# Register member
cast send <MEMBER_REGISTRY_ADDRESS> \
  "registerMember(string,string,string,uint8,bytes32)" \
  "TEST" "Test" "US" 1 "0x..." \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Get member details
cast call <MEMBER_REGISTRY_ADDRESS> \
  "getMemberDetails(string)" "TEST" \
  --rpc-url $RPC_URL
```

---

## Troubleshooting

### Deployment Fails
1. Check RPC connectivity: `cast block-number --rpc-url $RPC_URL`
2. Verify private key format (no 0x prefix)
3. Ensure sufficient AVAX balance
4. Check contract compilation: `forge build`

### Transaction Reverts
1. Check error message
2. Verify account has required role
3. Check contract state
4. Review transaction details: `cast tx <TX_HASH> --rpc-url $RPC_URL`

### Verification Fails
1. Ensure source code matches deployed bytecode
2. Use correct compiler version (0.8.20)
3. Set optimization to Yes (200 runs)
4. Include all dependencies

---

## Security Checklist

- [ ] Private key never committed to git
- [ ] `.env` file in `.gitignore`
- [ ] Contracts verified on SnowTrace
- [ ] Source code matches bytecode
- [ ] No hardcoded secrets in code
- [ ] Deployment addresses recorded securely
- [ ] Team notified of deployment

---

## Next Steps

After successful deployment:

1. **Phase 2 Implementation**
   - VaultRegistry
   - GoldAccountLedger
   - TransactionOrderBook
   - TransactionEventLogger
   - DocumentRegistry

2. **Integration Testing**
   - Test all contract interactions
   - Verify authorization flows
   - Test asset lifecycle

3. **Monitoring**
   - Monitor contract events
   - Track gas usage
   - Monitor for errors

---

## Support

### Documentation
- `DEPLOYMENT_GUIDE.md` - Detailed guide
- `DEPLOYMENT_CHECKLIST.md` - Step-by-step checklist
- `TECHNICAL_BREAKDOWN.md` - Implementation details

### Tools
- Foundry: https://book.getfoundry.sh
- SnowTrace: https://snowtrace.io
- Cast: https://book.getfoundry.sh/cast

---

**Status:** ✅ Ready for Deployment

**Estimated Time:** 10-15 minutes

**Next Milestone:** Phase 2 Implementation
