#!/bin/bash
set -euo pipefail

source .env
[ -z "${RPC_URL:-}" ] && { echo "❌ RPC_URL missing"; exit 1; }
[ -z "${PRIVATE_KEY:-}" ] && { echo "❌ PRIVATE_KEY missing"; exit 1; }

[[ "$PRIVATE_KEY" =~ ^0x ]] || PRIVATE_KEY="0x$PRIVATE_KEY"
DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")

echo "🚀 Deploying GIFT (deployer: $DEPLOYER)"

rm -rf cache/ out/ && forge build >/dev/null

OUT=$(PRIVATE_KEY="$PRIVATE_KEY" forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url "$RPC_URL" --broadcast 2>&1) || {
    echo "❌ Deploy failed"
    echo "$OUT" | tail -40
    exit 1
  }

MR=$(echo "$OUT" | grep -E "DEPLOYED_MEMBER_REGISTRY="     | tail -1 | cut -d= -f2 | tr -d '\r')
AL=$(echo "$OUT" | grep -E "DEPLOYED_GOLD_ACCOUNT_LEDGER=" | tail -1 | cut -d= -f2 | tr -d '\r')
GT=$(echo "$OUT" | grep -E "DEPLOYED_GOLD_ASSET_TOKEN="    | tail -1 | cut -d= -f2 | tr -d '\r')

[ -z "${MR:-}" ] || [ -z "${AL:-}" ] || [ -z "${GT:-}" ] && {
  echo "❌ Deploy failed (could not parse addresses)"
  echo "$OUT" | tail -40
  exit 1
}

echo "✅ Deployed"
echo "  MemberRegistry:    $MR"
echo "  GoldAccountLedger: $AL"
echo "  GoldAssetToken:    $GT"

mkdir -p deployments
cat > deployments/avalanche.json << EOF
{"network":"avalanche-l1","memberRegistry":"$MR","goldAccountLedger":"$AL","goldAssetToken":"$GT","deployer":"$DEPLOYER","timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
