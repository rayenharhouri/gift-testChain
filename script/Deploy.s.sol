// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/GoldAssetToken.sol";

contract DeployGIFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy MemberRegistry
        MemberRegistry memberRegistry = new MemberRegistry();
        vm.writeLine("stdout", string(abi.encodePacked("MemberRegistry: ", vm.toString(address(memberRegistry)))));

        // Deploy GoldAssetToken
        GoldAssetToken goldAssetToken = new GoldAssetToken(address(memberRegistry));
        vm.writeLine("stdout", string(abi.encodePacked("GoldAssetToken: ", vm.toString(address(goldAssetToken)))));

        vm.stopBroadcast();
    }
}
