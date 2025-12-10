# Network Configuration - Your Avalanche Network

**Fill in your network details below**

---

## Network Information

### Basic Details
- **Network Name:** [Your Network Name]
- **Chain ID:** [Your Chain ID]
- **RPC URL:** [Your RPC Endpoint]
- **Explorer URL:** [Your Block Explorer]
- **Currency:** [Your Token Name]
- **Currency Symbol:** [Symbol]

### Network Type
- [ ] Mainnet
- [ ] Testnet
- [ ] Custom/Private

---

## RPC Configuration

### Primary RPC
```
URL: [Your RPC URL]
Method: HTTP/HTTPS
Port: [Port Number]
```

### Backup RPC (Optional)
```
URL: [Backup RPC URL]
Method: HTTP/HTTPS
Port: [Port Number]
```

### RPC Test
```bash
# Test connectivity
curl -X POST [Your RPC URL] \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Expected response:
# {"jsonrpc":"2.0","result":"0x...","id":1}
```

---

## Deployment Configuration

### Deployer Account
- **Address:** 0x...
- **Private Key:** [Stored in .env]
- **Balance Required:** ~1 AVAX (or equivalent)

### Gas Settings
- **Gas Price:** [Network gas price]
- **Gas Limit:** 2,000,000 (for both contracts)
- **Estimated Cost:** ~1 AVAX

---

## Contract Deployment Addresses

### After Deployment
```json
{
  "network": "[Your Network Name]",
  "chainId": [Your Chain ID],
  "timestamp": "[Deployment Date]",
  "contracts": {
    "memberRegistry": "0x...",
    "goldAssetToken": "0x..."
  },
  "deployer": "0x...",
  "blockNumber": 0,
  "transactionHash": "0x..."
}
```

---

## Foundry Configuration

### Update foundry.toml
```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
solc = "0.8.20"

[profile.default.rpc_endpoints]
avalanche = "[Your RPC URL]"

[profile.default.etherscan]
avalanche = { key = "[Your Explorer API Key]", url = "[Your Explorer API URL]" }
```

---

## Environment Variables

### Create .env file
```bash
# Network
RPC_URL=[Your RPC URL]
CHAIN_ID=[Your Chain ID]

# Deployment
PRIVATE_KEY=[Your Private Key - no 0x prefix]
DEPLOYER_ADDRESS=0x...

# Verification (Optional)
ETHERSCAN_API_KEY=[Your Explorer API Key]
EXPLORER_URL=[Your Block Explorer URL]
```

---

## Deployment Commands

### Compile
```bash
forge build
```

### Deploy
```bash
source .env
forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Verify (if explorer supports it)
```bash
forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url $RPC_URL \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Network Specifications

### Consensus
- **Type:** [Proof of Stake / Other]
- **Validator Count:** [Number]
- **Block Time:** [Seconds]
- **Finality:** [Blocks]

### Capacity
- **Block Gas Limit:** [Gas]
- **Average Gas Price:** [Gwei]
- **TPS:** [Transactions per second]

### Compatibility
- **EVM Version:** [Version]
- **Solidity Support:** 0.8.20 ✅
- **OpenZeppelin Support:** Yes ✅

---

## Block Explorer

### Access
- **URL:** [Your Block Explorer]
- **API Endpoint:** [API URL]
- **API Key:** [Your API Key]

### Verification
- **Supports:** Source code verification
- **Compiler:** Solidity 0.8.20
- **Optimization:** Yes (200 runs)

---

## Monitoring & Support

### Monitoring Tools
- **Block Explorer:** [URL]
- **Status Page:** [URL]
- **Discord:** [Link]
- **Telegram:** [Link]

### Support Contacts
- **Technical Support:** [Contact]
- **Documentation:** [URL]
- **Community:** [Link]

---

## Pre-Deployment Checklist

- [ ] RPC URL tested and working
- [ ] Deployer account has sufficient balance
- [ ] Private key stored securely in .env
- [ ] .env file added to .gitignore
- [ ] Contracts compile without errors
- [ ] All tests pass locally
- [ ] Network configuration verified
- [ ] Block explorer accessible

---

## Post-Deployment Checklist

- [ ] Contracts deployed successfully
- [ ] Addresses recorded
- [ ] Contracts verified on explorer
- [ ] Functionality tested
- [ ] Documentation updated
- [ ] Team notified
- [ ] Deployment record created

---

## Troubleshooting

### RPC Connection Issues
```bash
# Test RPC
cast block-number --rpc-url $RPC_URL

# If fails, check:
# 1. RPC URL is correct
# 2. Network is accessible
# 3. No firewall blocking
# 4. RPC endpoint is running
```

### Insufficient Balance
```bash
# Check balance
cast balance $DEPLOYER_ADDRESS --rpc-url $RPC_URL

# If insufficient:
# 1. Send AVAX to deployer
# 2. Wait for confirmation
# 3. Retry deployment
```

### Deployment Fails
```bash
# Check error message
# Common issues:
# 1. Invalid private key format
# 2. Insufficient gas
# 3. Contract compilation error
# 4. Network connectivity issue
```

---

## Notes

[Add any additional notes about your network here]

---

**Last Updated:** [Date]
**Status:** Ready for Deployment ✅
