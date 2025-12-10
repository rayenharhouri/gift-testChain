// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/GoldAssetToken.sol";

contract DeployGIFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy MemberRegistry
        MemberRegistry memberRegistry = new MemberRegistry();
        console.log("MemberRegistry deployed at:", address(memberRegistry));

        // Step 2: Deploy GoldAssetToken with MemberRegistry address
        GoldAssetToken goldAssetToken = new GoldAssetToken(address(memberRegistry));
        console.log("GoldAssetToken deployed at:", address(goldAssetToken));

        vm.stopBroadcast();

        // Log deployment info
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("MemberRegistry:", address(memberRegistry));
        console.log("GoldAssetToken:", address(goldAssetToken));
    }
}
