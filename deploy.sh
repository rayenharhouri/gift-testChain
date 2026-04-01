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

# Optional but recommended
if [ -z "$CHAIN_ID" ]; then
    echo "❌ CHAIN_ID not set in .env"
    exit 1
fi

# Add 0x prefix if not present
if [[ ! "$PRIVATE_KEY" =~ ^0x ]]; then
    PRIVATE_KEY="0x$PRIVATE_KEY"
fi

DEPLOYER_ADDR=$(cast wallet address --private-key $PRIVATE_KEY)

echo "📋 Configuration:"
echo "  RPC: $RPC_URL"
echo "  Chain ID: $CHAIN_ID"
echo "  Deployer: $DEPLOYER_ADDR"
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
DOCUMENT_REGISTRY=$(echo "$DEPLOY_OUTPUT" | grep "DocumentRegistry:" | tail -1 | awk '{print $NF}')
GOLD_ASSET_TOKEN=$(echo "$DEPLOY_OUTPUT" | grep "GoldAssetToken:" | tail -1 | awk '{print $NF}')
ACCOUNT_LEDGER=$(echo "$DEPLOY_OUTPUT" | grep "GoldAccountLedger:" | tail -1 | awk '{print $NF}')
TRANSACTION_ORDER_BOOK=$(echo "$DEPLOY_OUTPUT" | grep "TransactionOrderBook:" | tail -1 | awk '{print $NF}')
VAULT_SITE_REGISTRY=$(echo "$DEPLOY_OUTPUT" | grep "VaultSiteRegistry:" | tail -1 | awk '{print $NF}')
VAULT_REGISTRY=$(echo "$DEPLOY_OUTPUT" | grep "VaultRegistry:" | tail -1 | awk '{print $NF}')

if [ -z "$MEMBER_REGISTRY" ] || [ -z "$DOCUMENT_REGISTRY" ] || [ -z "$GOLD_ASSET_TOKEN" ] || [ -z "$ACCOUNT_LEDGER" ] || [ -z "$TRANSACTION_ORDER_BOOK" ] || [ -z "$VAULT_SITE_REGISTRY" ] || [ -z "$VAULT_REGISTRY" ]; then
    echo "   ❌ Deployment failed"
    echo "$DEPLOY_OUTPUT" | tail -30
    exit 1
fi

echo "   ✅ MemberRegistry: $MEMBER_REGISTRY"
echo "   ✅ DocumentRegistry: $DOCUMENT_REGISTRY"
echo "   ✅ GoldAssetToken: $GOLD_ASSET_TOKEN"
echo "   ✅ GoldAccountLedger: $ACCOUNT_LEDGER"
echo "   ✅ TransactionOrderBook: $TRANSACTION_ORDER_BOOK"
echo "   ✅ VaultSiteRegistry: $VAULT_SITE_REGISTRY"
echo "   ✅ VaultRegistry: $VAULT_REGISTRY"
echo ""

# Verify
echo "3️⃣  Verifying deployment..."
MEMBERS_COUNT=$(cast call "$MEMBER_REGISTRY" "getMembersCount()" --rpc-url "$RPC_URL")
echo "   ✅ MemberRegistry members: $MEMBERS_COUNT"

VSR_IDS=$(cast call "$VAULT_SITE_REGISTRY" "getVaultSiteIds()" --rpc-url "$RPC_URL")
echo "   ✅ VaultSiteRegistry getVaultSiteIds(): $VSR_IDS"

VR_IDS=$(cast call "$VAULT_REGISTRY" "getAllVaultIds()" --rpc-url "$RPC_URL")
echo "   ✅ VaultRegistry getAllVaultIds(): $VR_IDS"
echo " "

# ✅ Configure ledger: allow GoldAssetToken to call updateBalanceFromContract
echo "4️⃣  Configuring GoldAccountLedger balance updater..."
SET_TX_OUTPUT=$(cast send "$ACCOUNT_LEDGER" \
  "setBalanceUpdater(address,bool)" "$GOLD_ASSET_TOKEN" true \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --chain-id "$CHAIN_ID" 2>&1)

if [ $? -ne 0 ]; then
    echo "   ❌ setBalanceUpdater failed"
    echo "$SET_TX_OUTPUT" | tail -30
    exit 1
fi

echo "   ✅ setBalanceUpdater(GoldAssetToken,true) sent"
echo ""

# (Optional) read back to confirm
UPDATER_ALLOWED=$(cast call "$ACCOUNT_LEDGER" "balanceUpdaters(address)(bool)" "$GOLD_ASSET_TOKEN" --rpc-url "$RPC_URL")
echo "   ✅ balanceUpdaters(GoldAssetToken): $UPDATER_ALLOWED"
echo ""

# Save deployment info
mkdir -p deployments
cat > deployments/avalanche.json << EOF
{
  "network": "avalanche",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "memberRegistry": "$MEMBER_REGISTRY",
  "documentRegistry": "$DOCUMENT_REGISTRY",
  "goldAssetToken": "$GOLD_ASSET_TOKEN",
  "goldAccountLedger": "$ACCOUNT_LEDGER",
  "transactionOrderBook": "$TRANSACTION_ORDER_BOOK",
  "vaultSiteRegistry": "$VAULT_SITE_REGISTRY",
  "vaultRegistry": "$VAULT_REGISTRY",
  "deployer": "$DEPLOYER_ADDR",
  "chainId": "$CHAIN_ID"
}
EOF

echo "✅ DEPLOYMENT COMPLETE"
echo ""
echo "Addresses:"
echo "  MemberRegistry:     $MEMBER_REGISTRY"
echo "  DocumentRegistry:   $DOCUMENT_REGISTRY"
echo "  GoldAssetToken:     $GOLD_ASSET_TOKEN"
echo "  GoldAccountLedger:  $ACCOUNT_LEDGER"
echo "  TransactionOrderBook: $TRANSACTION_ORDER_BOOK"
echo "  VaultSiteRegistry:  $VAULT_SITE_REGISTRY"
echo "  VaultRegistry:      $VAULT_REGISTRY"
