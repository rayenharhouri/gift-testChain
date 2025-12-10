#!/bin/bash

# Manual deployment using cast (no forge caching)

echo "🚀 GIFT Blockchain - Manual Deployment"
echo ""

source .env

if [ -z "$RPC_URL" ] || [ -z "$PRIVATE_KEY" ]; then
    echo "❌ RPC_URL or PRIVATE_KEY not set in .env"
    exit 1
fi

DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)
echo "Deployer: $DEPLOYER"
echo ""

# Step 1: Deploy MemberRegistry
echo "1️⃣  Deploying MemberRegistry..."
MR_BYTECODE=$(cat out/MemberRegistry.sol/MemberRegistry.json | jq -r '.bytecode.object')
MR_TX=$(cast send --private-key $PRIVATE_KEY --rpc-url $RPC_URL --create $MR_BYTECODE 2>&1 | grep "transactionHash" | awk '{print $NF}' | tr -d '"')

if [ -z "$MR_TX" ]; then
    echo "   ❌ Failed"
    exit 1
fi

MEMBER_REGISTRY=$(cast receipt $MR_TX --rpc-url $RPC_URL | grep "contractAddress" | awk '{print $NF}' | tr -d '"')
echo "   ✅ MemberRegistry: $MEMBER_REGISTRY"
echo ""

# Step 2: Deploy GoldAssetToken with MemberRegistry address
echo "2️⃣  Deploying GoldAssetToken..."
GAT_BYTECODE=$(cat out/GoldAssetToken.sol/GoldAssetToken.json | jq -r '.bytecode.object')
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" $MEMBER_REGISTRY)
GAT_FULL_BYTECODE="${GAT_BYTECODE}${CONSTRUCTOR_ARGS:2}"

GAT_TX=$(cast send --private-key $PRIVATE_KEY --rpc-url $RPC_URL --create $GAT_FULL_BYTECODE 2>&1 | grep "transactionHash" | awk '{print $NF}' | tr -d '"')

if [ -z "$GAT_TX" ]; then
    echo "   ❌ Failed"
    exit 1
fi

GOLD_ASSET_TOKEN=$(cast receipt $GAT_TX --rpc-url $RPC_URL | grep "contractAddress" | awk '{print $NF}' | tr -d '"')
echo "   ✅ GoldAssetToken: $GOLD_ASSET_TOKEN"
echo ""

# Save deployment info
mkdir -p deployments
cat > deployments/avalanche.json << EOF
{
  "network": "avalanche",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "memberRegistry": "$MEMBER_REGISTRY",
  "goldAssetToken": "$GOLD_ASSET_TOKEN",
  "deployer": "$DEPLOYER"
}
EOF

echo "✅ DEPLOYMENT COMPLETE"
echo ""
echo "Addresses:"
echo "  MemberRegistry:  $MEMBER_REGISTRY"
echo "  GoldAssetToken:  $GOLD_ASSET_TOKEN"
