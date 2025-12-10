# GIFT Blockchain - Avalanche Deployment Guide

## Prerequisites

1. **Foundry installed**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Avalanche RPC URL** - Your custom network RPC endpoint
3. **Private Key** - Deployer wallet private key
4. **AVAX tokens** - For gas fees

---

## Setup

### 1. Clone Environment Variables
```bash
cp .env.example .env
```

### 2. Edit .env with Your Values
```bash
nano .env
```

**Required values:**
- `RPC_URL` - Your Avalanche RPC endpoint
- `PRIVATE_KEY` - Your deployer private key (without 0x prefix)
- `ETHERSCAN_API_KEY` - SnowTrace API key (optional, for verification)

---

## Deployment Steps

### Step 1: Verify Contracts Compile
```bash
forge build
```

### Step 2: Deploy to Avalanche
```bash
source .env
forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Step 3: Verify Deployment
```bash
forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url $RPC_URL \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Expected Output

```
MemberRegistry deployed at: 0x...
GoldAssetToken deployed at: 0x...

=== DEPLOYMENT COMPLETE ===
MemberRegistry: 0x...
GoldAssetToken: 0x...
```

---

## Post-Deployment

### 1. Save Contract Addresses
```bash
# Create deployment record
cat > deployments/avalanche.json << EOF
{
  "network": "avalanche",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "memberRegistry": "0x...",
  "goldAssetToken": "0x...",
  "deployer": "0x...",
  "blockNumber": 12345678
}
EOF
```

### 2. Initialize System
```bash
# Link deployer as PLATFORM admin (already done in constructor)
# Link governance address
cast send <MEMBER_REGISTRY_ADDRESS> \
  "linkAddressToMember(address,string)" \
  <GOVERNANCE_ADDRESS> \
  "GOVERNANCE" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### 3. Register First Member
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

---

## Troubleshooting

### "Insufficient funds"
- Ensure deployer wallet has AVAX for gas
- Typical gas cost: 0.5-1 AVAX

### "RPC connection failed"
- Verify RPC URL is correct
- Check network connectivity
- Test with: `cast block-number --rpc-url $RPC_URL`

### "Private key invalid"
- Remove 0x prefix if present
- Ensure 64 hex characters
- Check key has no spaces

### "Contract already deployed"
- Use different deployer address
- Or deploy to different network

---

## Network Information

### Avalanche Mainnet
- **Chain ID:** 43114
- **RPC:** https://api.avax.network/ext/bc/C/rpc
- **Explorer:** https://snowtrace.io
- **Currency:** AVAX

### Avalanche Testnet (Fuji)
- **Chain ID:** 43113
- **RPC:** https://api.avax-test.network/ext/bc/C/rpc
- **Explorer:** https://testnet.snowtrace.io
- **Faucet:** https://faucet.avax.network

---

## Verification on SnowTrace

### Automatic Verification
```bash
forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url $RPC_URL \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --broadcast
```

### Manual Verification
1. Go to https://snowtrace.io
2. Search for contract address
3. Click "Verify and Publish"
4. Upload source code
5. Select compiler version: 0.8.20
6. Set optimization: Yes (200 runs)

---

## Contract Interaction

### Check Member Status
```bash
cast call <MEMBER_REGISTRY_ADDRESS> \
  "getMemberStatus(string)" \
  "GIFTCHZZ" \
  --rpc-url $RPC_URL
```

### Mint Gold Asset
```bash
cast send <GOLD_ASSET_TOKEN_ADDRESS> \
  "mint(address,string,string,uint256,uint256,uint8,bytes32,string,bool)" \
  <OWNER_ADDRESS> \
  "SN123456" \
  "Refiner A" \
  1000000 \
  9999 \
  0 \
  "0xabc..." \
  "GIFTCHZZ" \
  true \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

---

## Gas Estimates

| Operation | Gas | Cost (AVAX) |
|-----------|-----|-------------|
| Deploy MemberRegistry | ~800,000 | ~0.4 |
| Deploy GoldAssetToken | ~1,200,000 | ~0.6 |
| Register Member | ~100,000 | ~0.05 |
| Mint Asset | ~150,000 | ~0.075 |
| Update Status | ~50,000 | ~0.025 |

**Total deployment cost:** ~1 AVAX

---

## Security Notes

⚠️ **IMPORTANT:**
- Never commit `.env` file to git
- Use hardware wallet for mainnet
- Test on testnet first
- Verify contract addresses before interaction
- Keep private keys secure

---

## Support

For issues:
1. Check contract compilation: `forge build`
2. Verify RPC connectivity: `cast block-number --rpc-url $RPC_URL`
3. Check account balance: `cast balance <ADDRESS> --rpc-url $RPC_URL`
4. Review transaction: `cast tx <TX_HASH> --rpc-url $RPC_URL`

---

**Status:** Ready for Deployment ✅
