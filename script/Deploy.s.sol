// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/GoldAssetToken.sol";
import "../contracts/GoldAccountLedger.sol";

contract DeployGIFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MemberRegistry
        MemberRegistry memberRegistry = new MemberRegistry();
        console.log("MemberRegistry:", address(memberRegistry));

        // Deploy GoldAccountLedger
        GoldAccountLedger accountLedger = new GoldAccountLedger(address(memberRegistry));
        console.log("GoldAccountLedger:", address(accountLedger));

        // Deploy GoldAssetToken
        GoldAssetToken goldAssetToken = new GoldAssetToken(address(memberRegistry), address(accountLedger));
        console.log("GoldAssetToken:", address(goldAssetToken));

        vm.stopBroadcast();
    }
}
