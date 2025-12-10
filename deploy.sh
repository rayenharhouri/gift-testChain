#!/bin/bash
set -e

# GIFT Avalanche L1 Deployment Script
# Usage: ./deploy.sh

echo "🚀 GIFT Blockchain - Avalanche L1 Deployment"
echo ""

# Load environment
if [ ! -f .env ]; then
    echo "❌ .env file not found. Run: cp .env.example .env"
    exit 1
fi

source .env

if [ -z "$RPC_URL" ] || [ -z "$PRIVATE_KEY" ]; then
    echo "❌ RPC_URL or PRIVATE_KEY not set in .env"
    exit 1
fi

if [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "⚠️  ETHERSCAN_API_KEY not set (verification skipped)"
fi

echo "📋 Configuration:"
echo "  RPC: $RPC_URL"
echo "  Deployer: $(cast wallet address --private-key $PRIVATE_KEY)"
echo ""

# Step 1: Compile
echo "1️⃣  Compiling contracts..."
forge build
echo "   ✅ Done"
echo ""

# Step 2: Deploy MemberRegistry
echo "2️⃣  Deploying MemberRegistry..."
MEMBER_REGISTRY=$(forge create contracts/MemberRegistry.sol:MemberRegistry \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast 2>&1 | grep "Deployed to:" | awk '{print $NF}')

echo "   ✅ MemberRegistry: $MEMBER_REGISTRY"
echo ""

# Step 3: Deploy GoldAssetToken
echo "3️⃣  Deploying GoldAssetToken..."
DEPLOY_OUTPUT=$(forge create contracts/GoldAssetToken.sol:GoldAssetToken \
  --constructor-args $MEMBER_REGISTRY \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast 2>&1)

GOLD_ASSET_TOKEN=$(echo "$DEPLOY_OUTPUT" | grep "Deployed to:" | awk '{print $NF}')

if [ -z "$GOLD_ASSET_TOKEN" ]; then
    echo "   ❌ Deployment failed"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo "   ✅ GoldAssetToken: $GOLD_ASSET_TOKEN"
echo ""

# Step 4: Verify
echo "4️⃣  Verifying deployment..."
MEMBERS_COUNT=$(cast call $MEMBER_REGISTRY "getMembersCount()" --rpc-url $RPC_URL)
echo "   ✅ MemberRegistry members: $MEMBERS_COUNT"
echo ""

# Save deployment info
mkdir -p deployments
cat > deployments/avalanche.json << EOF
{
  "network": "avalanche",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "memberRegistry": "$MEMBER_REGISTRY",
  "goldAssetToken": "$GOLD_ASSET_TOKEN",
  "deployer": "$(cast wallet address --private-key $PRIVATE_KEY)"
}
EOF

echo "📝 Deployment saved to: deployments/avalanche.json"
echo ""
echo "✅ DEPLOYMENT COMPLETE"
echo ""
echo "Addresses:"
echo "  MemberRegistry:  $MEMBER_REGISTRY"
echo "  GoldAssetToken:  $GOLD_ASSET_TOKEN"
echo ""
echo "Next: Read AVALANCHE_L1_DEPLOY.md for initialization steps"
