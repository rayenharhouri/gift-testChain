#!/bin/bash

# GIFT Blockchain - Avalanche Deployment Commands
# Copy and paste these commands in order

echo "=== GIFT Blockchain Deployment to Avalanche ==="
echo ""

# ============================================
# STEP 1: SETUP ENVIRONMENT
# ============================================
echo "STEP 1: Setup Environment"
echo "=========================="
echo ""
echo "1a. Copy environment template:"
echo "    cp .env.example .env"
echo ""
echo "1b. Edit .env file with your values:"
echo "    nano .env"
echo ""
echo "    Required values:"
echo "    - RPC_URL= http://127.0.0.1:9654/ext/bc/PMwUb6MbsC32Qj86NGeFBkKJyQkehvr9xumqnEk3ryWL9FEBP/rpc"
echo "    - PRIVATE_KEY=your_private_key_without_0x"
echo "    - ETHERSCAN_API_KEY=your_api_key (optional)"
echo ""
echo "1c. Test RPC connectivity:"
echo "    cast block-number --rpc-url <YOUR_RPC_URL>"
echo ""
echo "1d. Check deployer balance:"
echo "    cast balance <YOUR_ADDRESS> --rpc-url <YOUR_RPC_URL>"
echo ""
read -p "Press Enter when Step 1 is complete..."

# ============================================
# STEP 2: COMPILE CONTRACTS
# ============================================
echo ""
echo "STEP 2: Compile Contracts"
echo "========================="
echo ""
echo "Running: forge build"
echo ""
forge build

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful"
else
    echo "❌ Compilation failed"
    exit 1
fi

read -p "Press Enter to continue to deployment..."

# ============================================
# STEP 3: DEPLOY CONTRACTS
# ============================================
echo ""
echo "STEP 3: Deploy Contracts to Avalanche"
echo "======================================"
echo ""
echo "Loading environment variables..."
source .env

echo ""
echo "Deploying to Avalanche..."
echo "RPC URL: $RPC_URL"
echo ""

forge script script/Deploy.s.sol:DeployGIFT \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
else
    echo ""
    echo "❌ Deployment failed"
    exit 1
fi

read -p "Press Enter to continue to verification..."

# ============================================
# STEP 4: VERIFY CONTRACTS (OPTIONAL)
# ============================================
echo ""
echo "STEP 4: Verify Contracts on Explorer (Optional)"
echo "==============================================="
echo ""
echo "If you have an Etherscan API key, run:"
echo ""
echo "forge script script/Deploy.s.sol:DeployGIFT \\"
echo "  --rpc-url $RPC_URL \\"
echo "  --verify \\"
echo "  --etherscan-api-key $ETHERSCAN_API_KEY"
echo ""

read -p "Press Enter when verification is complete..."

# ============================================
# STEP 5: RECORD DEPLOYMENT
# ============================================
echo ""
echo "STEP 5: Record Deployment Information"
echo "====================================="
echo ""
echo "Save the following information:"
echo ""
echo "1. MemberRegistry address: 0x..."
echo "2. GoldAssetToken address: 0x..."
echo "3. Deployer address: 0x..."
echo "4. Block number: ..."
echo "5. Transaction hash: 0x..."
echo ""
echo "Create a file: deployments/avalanche.json"
echo ""
echo "Example:"
echo "{"
echo "  \"network\": \"avalanche\","
echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
echo "  \"memberRegistry\": \"0x....\","
echo "  \"goldAssetToken\": \"0x....\","
echo "  \"deployer\": \"0x....\","
echo "  \"blockNumber\": 0,"
echo "  \"txHash\": \"0x....\""
echo "}"
echo ""

read -p "Press Enter when deployment information is saved..."

# ============================================
# STEP 6: VERIFY DEPLOYMENT
# ============================================
echo ""
echo "STEP 6: Verify Deployment"
echo "========================="
echo ""
echo "Test MemberRegistry:"
echo "cast call <MEMBER_REGISTRY_ADDRESS> \"getMembersCount()\" --rpc-url $RPC_URL"
echo ""
echo "Test GoldAssetToken:"
echo "cast call <GOLD_ASSET_TOKEN_ADDRESS> \"owner()\" --rpc-url $RPC_URL"
echo ""

read -p "Press Enter when verification is complete..."

# ============================================
# STEP 7: INITIALIZE SYSTEM
# ============================================
echo ""
echo "STEP 7: Initialize System"
echo "========================="
echo ""
echo "Link governance address:"
echo "cast send <MEMBER_REGISTRY_ADDRESS> \\"
echo "  \"linkAddressToMember(address,string)\" \\"
echo "  <GOVERNANCE_ADDRESS> \\"
echo "  \"GOVERNANCE\" \\"
echo "  --rpc-url $RPC_URL \\"
echo "  --private-key $PRIVATE_KEY"
echo ""
echo "Register first member:"
echo "cast send <MEMBER_REGISTRY_ADDRESS> \\"
echo "  \"registerMember(string,string,string,uint8,bytes32)\" \\"
echo "  \"GIFTCHZZ\" \\"
echo "  \"Swiss Refinery\" \\"
echo "  \"CH\" \\"
echo "  1 \\"
echo "  \"0x$(echo -n 'member_data' | sha256sum | cut -d' ' -f1)\" \\"
echo "  --rpc-url $RPC_URL \\"
echo "  --private-key $PRIVATE_KEY"
echo ""

read -p "Press Enter when system initialization is complete..."

# ============================================
# COMPLETION
# ============================================
echo ""
echo "=== DEPLOYMENT COMPLETE ==="
echo ""
echo "✅ Contracts deployed to Avalanche"
echo "✅ Deployment verified"
echo "✅ System initialized"
echo ""
echo "Next steps:"
echo "1. Update documentation with contract addresses"
echo "2. Notify team of deployment"
echo "3. Begin Phase 2 implementation"
echo ""
echo "Documentation files:"
echo "- DEPLOYMENT_GUIDE.md"
echo "- DEPLOYMENT_CHECKLIST.md"
echo "- AVALANCHE_DEPLOYMENT.md"
echo ""
