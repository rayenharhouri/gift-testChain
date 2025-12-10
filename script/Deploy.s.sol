// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/GoldAssetToken.sol";

contract DeployGIFT is Script {
    function run() external {
        // Read private key from environment (with or without 0x prefix)
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MemberRegistry
        MemberRegistry memberRegistry = new MemberRegistry();
        console.log("MemberRegistry:", address(memberRegistry));

        // Deploy GoldAssetToken
        GoldAssetToken goldAssetToken = new GoldAssetToken(address(memberRegistry));
        console.log("GoldAssetToken:", address(goldAssetToken));

        vm.stopBroadcast();
    }
}
