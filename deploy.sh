#!/bin/bash
set -euo pipefail

echo "🚀 GIFT Blockchain - Avalanche L1 Deployment"
echo ""

source .env

if [ -z "${RPC_URL:-}" ] || [ -z "${PRIVATE_KEY:-}" ]; then
  echo "❌ RPC_URL or PRIVATE_KEY not set in .env"
  exit 1
fi

# Add 0x prefix if not present (for cast wallet address --private-key)
if [[ ! "$PRIVATE_KEY" =~ ^0x ]]; then
  PRIVATE_KEY="0x$PRIVATE_KEY"
fi

DEPLOYER_ADDR=$(cast wallet address --private-key "$PRIVATE_KEY")

echo "📋 Configuration:"
echo "  RPC:      $RPC_URL"
echo "  Deployer: $DEPLOYER_ADDR"
echo ""

# Clean + build
rm -rf cache/ out/
echo "1️⃣  Compiling contracts..."
forge build
echo "   ✅ Done"
echo ""

# Deploy using forge script
echo "2️⃣  Deploying contracts..."
set +e
DEPLOY_OUTPUT=$(PRIVATE_KEY="$PRIVATE_KEY" forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url "$RPC_URL" \
  --broadcast \
  --json 2>&1)
STATUS=$?
set -e

if [ $STATUS -ne 0 ]; then
  echo "   ❌ Deployment failed (forge script returned $STATUS)"
  echo ""
  echo "---- forge output (tail) ----"
  echo "$DEPLOY_OUTPUT" | tail -120
  exit 1
fi

# Parse addresses printed by Deploy.s.sol with stable prefixes:
# DEPLOYED_MEMBER_REGISTRY=0x...
# DEPLOYED_GOLD_ACCOUNT_LEDGER=0x...
# DEPLOYED_GOLD_ASSET_TOKEN=0x...
MEMBER_REGISTRY=$(echo "$DEPLOY_OUTPUT" | grep -E "DEPLOYED_MEMBER_REGISTRY=" | tail -1 | cut -d= -f2 | tr -d '\r')
ACCOUNT_LEDGER=$(echo "$DEPLOY_OUTPUT" | grep -E "DEPLOYED_GOLD_ACCOUNT_LEDGER=" | tail -1 | cut -d= -f2 | tr -d '\r')
GOLD_ASSET_TOKEN=$(echo "$DEPLOY_OUTPUT" | grep -E "DEPLOYED_GOLD_ASSET_TOKEN=" | tail -1 | cut -d= -f2 | tr -d '\r')

if [ -z "${MEMBER_REGISTRY:-}" ] || [ -z "${ACCOUNT_LEDGER:-}" ] || [ -z "${GOLD_ASSET_TOKEN:-}" ]; then
  echo "   ❌ Deployment failed (could not parse contract addresses)"
  echo ""
  echo "---- forge output (tail) ----"
  echo "$DEPLOY_OUTPUT" | tail -120
  exit 1
fi

echo "   ✅ DEPLOYMENT SUCCESS"
echo "   ✅ MemberRegistry:     $MEMBER_REGISTRY"
echo "   ✅ GoldAccountLedger:  $ACCOUNT_LEDGER"
echo "   ✅ GoldAssetToken:     $GOLD_ASSET_TOKEN"
echo ""

# Verify (basic sanity checks)
echo "3️⃣  Verifying deployment..."

MEMBERS_COUNT=$(cast call "$MEMBER_REGISTRY" "getMembersCount()" --rpc-url "$RPC_URL")
echo "   ✅ MemberRegistry members: $MEMBERS_COUNT"

TOKEN_MEMBER_REGISTRY=$(cast call "$GOLD_ASSET_TOKEN" "memberRegistry()(address)" --rpc-url "$RPC_URL")
TOKEN_LEDGER=$(cast call "$GOLD_ASSET_TOKEN" "accountLedger()(address)" --rpc-url "$RPC_URL")

echo "   ✅ Token.memberRegistry(): $TOKEN_MEMBER_REGISTRY"
echo "   ✅ Token.accountLedger():  $TOKEN_LEDGER"

# Normalize to lowercase for comparison
if [ "${TOKEN_MEMBER_REGISTRY,,}" != "${MEMBER_REGISTRY,,}" ]; then
  echo "   ❌ Token is pointing to wrong MemberRegistry"
  exit 1
fi

if [ "${TOKEN_LEDGER,,}" != "${ACCOUNT_LEDGER,,}" ]; then
  echo "   ❌ Token is pointing to wrong AccountLedger"
  exit 1
fi

echo "   ✅ Wiring looks correct"
echo ""

# Save deployment info
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
