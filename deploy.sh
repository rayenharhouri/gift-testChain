#!/bin/bash
set -euo pipefail

echo "🚀 GIFT Blockchain - Avalanche L1 Deployment"
echo ""

source .env

if [ -z "${RPC_URL:-}" ] || [ -z "${PRIVATE_KEY:-}" ]; then
  echo "❌ RPC_URL or PRIVATE_KEY not set in .env"
  exit 1
fi

# Add 0x prefix if not present (needed for cast wallet address --private-key)
if [[ ! "$PRIVATE_KEY" =~ ^0x ]]; then
  PRIVATE_KEY="0x$PRIVATE_KEY"
fi

DEPLOYER_ADDR=$(cast wallet address --private-key "$PRIVATE_KEY")

echo "📋 Configuration:"
echo "  RPC:      $RPC_URL"
echo "  Deployer: $DEPLOYER_ADDR"
echo ""

rm -rf cache/ out/
echo "1️⃣  Compiling contracts..."
forge build
echo "   ✅ Done"
echo ""

echo "2️⃣  Deploying contracts..."
DEPLOY_OUTPUT=$(PRIVATE_KEY="$PRIVATE_KEY" forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url "$RPC_URL" \
  --broadcast 2>&1)

MEMBER_REGISTRY=$(echo "$DEPLOY_OUTPUT" | grep "MemberRegistry:"     | tail -1 | awk '{print $NF}')
ACCOUNT_LEDGER=$(echo "$DEPLOY_OUTPUT" | grep "GoldAccountLedger:"   | tail -1 | awk '{print $NF}')
GOLD_ASSET_TOKEN=$(echo "$DEPLOY_OUTPUT" | grep "GoldAssetToken:"    | tail -1 | awk '{print $NF}')

if [ -z "${MEMBER_REGISTRY:-}" ] || [ -z "${ACCOUNT_LEDGER:-}" ] || [ -z "${GOLD_ASSET_TOKEN:-}" ]; then
  echo "   ❌ Deployment failed (could not parse addresses)"
  echo ""
  echo "---- forge output (tail) ----"
  echo "$DEPLOY_OUTPUT" | tail -60
  exit 1
fi

echo "   ✅ MemberRegistry:    $MEMBER_REGISTRY"
echo "   ✅ GoldAccountLedger: $ACCOUNT_LEDGER"
echo "   ✅ GoldAssetToken:    $GOLD_ASSET_TOKEN"
echo ""

echo "3️⃣  Verifying deployment..."

# 3.1 MemberRegistry bootstrap sanity
MEMBERS_COUNT=$(cast call "$MEMBER_REGISTRY" "getMembersCount()" --rpc-url "$RPC_URL")
echo "   ✅ MemberRegistry members: $MEMBERS_COUNT"

# 3.2 GoldAssetToken wiring sanity
TOKEN_MEMBER_REGISTRY=$(cast call "$GOLD_ASSET_TOKEN" "memberRegistry()(address)" --rpc-url "$RPC_URL")
TOKEN_LEDGER=$(cast call "$GOLD_ASSET_TOKEN" "accountLedger()(address)" --rpc-url "$RPC_URL")

echo "   ✅ Token.memberRegistry(): $TOKEN_MEMBER_REGISTRY"
echo "   ✅ Token.accountLedger():  $TOKEN_LEDGER"

if [ "${TOKEN_MEMBER_REGISTRY,,}" != "${MEMBER_REGISTRY,,}" ]; then
  echo "   ❌ Token is pointing to wrong MemberRegistry"
  exit 1
fi

if [ "${TOKEN_LEDGER,,}" != "${ACCOUNT_LEDGER,,}" ]; then
  echo "   ❌ Token is pointing to wrong AccountLedger"
  exit 1
fi

echo ""

mkdir -p deployments
cat > deployments/avalanche.json << EOF
{
  "network": "avalanche-l1",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "memberRegistry": "$MEMBER_REGISTRY",
  "goldAccountLedger": "$ACCOUNT_LEDGER",
  "goldAssetToken": "$GOLD_ASSET_TOKEN",
  "deployer": "$DEPLOYER_ADDR"
}
EOF

echo "✅ DEPLOYMENT COMPLETE"
echo ""
echo "Addresses:"
echo "  MemberRegistry:     $MEMBER_REGISTRY"
echo "  GoldAccountLedger:  $ACCOUNT_LEDGER"
echo "  GoldAssetToken:     $GOLD_ASSET_TOKEN"
