#!/bin/bash

echo "🚀 GIFT Blockchain - Avalanche L1 Deployment"
echo ""

set -a
source .env
set +a


if [ -z "$RPC_URL" ] || [ -z "$PRIVATE_KEY" ]; then
    echo "❌ RPC_URL or PRIVATE_KEY not set in .env"
    exit 1
fi

# Add 0x prefix if not present
if [[ ! "$PRIVATE_KEY" =~ ^0x ]]; then
    PRIVATE_KEY="0x$PRIVATE_KEY"
fi

echo "📋 Configuration:"
echo "  RPC: $RPC_URL"
echo "  Deployer: $(cast wallet address --private-key $PRIVATE_KEY)"
echo ""

# Clean and build
rm -rf cache/ out/
echo "1️⃣  Compiling contracts..."
forge build
echo "   ✅ Done"
echo ""

# Deploy using forge script
echo "2️⃣  Deploying contracts..."
DEPLOY_OUTPUT=$(PRIVATE_KEY="$PRIVATE_KEY" forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url "$RPC_URL" \
  --broadcast 2>&1)

MEMBER_REGISTRY=$(echo "$DEPLOY_OUTPUT" | grep "MemberRegistry:" | tail -1 | awk '{print $NF}')
GOLD_ASSET_TOKEN=$(echo "$DEPLOY_OUTPUT" | grep "GoldAssetToken:" | tail -1 | awk '{print $NF}')
ACCOUNT_LEDGER=$(echo "$DEPLOY_OUTPUT" | grep "GoldAccountLedger:" | tail -1 | awk '{print $NF}')


if [ -z "$MEMBER_REGISTRY" ] || [ -z "$GOLD_ASSET_TOKEN" ] || [ -z "$ACCOUNT_LEDGER" ]; then
    echo "   ❌ Deployment failed"
    echo "$DEPLOY_OUTPUT" | tail -30
    exit 1
fi

echo "   ✅ MemberRegistry: $MEMBER_REGISTRY"
echo "   ✅ GoldAssetToken: $GOLD_ASSET_TOKEN"
echo "   ✅ GoldAssetToken: $ACCOUNT_LEDGER"
echo ""

# Verify
echo "3️⃣  Verifying deployment..."
MEMBERS_COUNT=$(cast call "$MEMBER_REGISTRY" "getMembersCount()" --rpc-url "$RPC_URL")
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
  "GoldAccountLedger": "$ACCOUNT_LEDGER",
  "deployer": "$(cast wallet address --private-key $PRIVATE_KEY)"
}
EOF

echo "✅ DEPLOYMENT COMPLETE"
echo ""
echo "Addresses:"
echo "  MemberRegistry:  $MEMBER_REGISTRY"
echo "  GoldAssetToken:  $GOLD_ASSET_TOKEN"
echo "  GoldAccountLedger:  $ACCOUNT_LEDGER"
