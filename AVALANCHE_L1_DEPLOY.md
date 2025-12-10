# Deploy to Avalanche L1 - Step by Step

## Prerequisites
- Foundry installed (`forge --version`)
- Private key with AVAX balance (testnet or mainnet)
- RPC URL for Avalanche

## Step 1: Setup Environment

```bash
cd /home/fsociety/GIFT
cp .env.example .env
```

Edit `.env`:
```
RPC_URL=https://api.avax.network/ext/bc/C/rpc          # Mainnet
# OR
RPC_URL=https://api.avax-test.network/ext/bc/C/rpc     # Testnet

PRIVATE_KEY=your_private_key_here                       # Without 0x prefix
ETHERSCAN_API_KEY=your_snowtrace_key                    # Optional
```

Verify connection:
```bash
cast block-number --rpc-url $RPC_URL
cast balance $(cast wallet address --private-key $PRIVATE_KEY) --rpc-url $RPC_URL
```

## Step 2: Compile

```bash
forge build
```

## Step 3: Deploy MemberRegistry

```bash
forge create contracts/MemberRegistry.sol:MemberRegistry \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**Save the address** → `MEMBER_REGISTRY_ADDRESS`

## Step 4: Deploy GoldAssetToken

```bash
forge create contracts/GoldAssetToken.sol:GoldAssetToken \
  --constructor-args $MEMBER_REGISTRY_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**Save the address** → `GOLD_ASSET_TOKEN_ADDRESS`

## Step 5: Verify Deployment

```bash
# Check MemberRegistry
cast call $MEMBER_REGISTRY_ADDRESS "getMembersCount()" --rpc-url $RPC_URL

# Check GoldAssetToken owner
cast call $GOLD_ASSET_TOKEN_ADDRESS "owner()" --rpc-url $RPC_URL
```

## Done ✅

Both contracts are now live on Avalanche L1.

### What's deployed:
- **MemberRegistry**: Authorization hub (8 roles, member management)
- **GoldAssetToken**: ERC1155 gold asset NFTs

### Next: Initialize System

Link your governance address:
```bash
cast send $MEMBER_REGISTRY_ADDRESS \
  "linkAddressToMember(address,string)" \
  $(cast wallet address --private-key $PRIVATE_KEY) \
  "GOVERNANCE" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

Register first member:
```bash
cast send $MEMBER_REGISTRY_ADDRESS \
  "registerMember(string,string,string,uint8,bytes32)" \
  "REFINER_ID" \
  "Refinery Name" \
  "CH" \
  1 \
  "0x$(echo -n 'member_data' | sha256sum | cut -d' ' -f1)" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

---

**Estimated gas cost**: ~1-2 AVAX  
**Time**: ~5 minutes
