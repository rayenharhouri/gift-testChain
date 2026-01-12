// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/GoldAccountLedger.sol";
import "../contracts/GoldAssetToken.sol";
import "../contracts/VaultSiteRegistry.sol";
import "../contracts/VaultRegistry.sol";

contract DeployGIFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MemberRegistry memberRegistry = new MemberRegistry();
        console.log("MemberRegistry:", address(memberRegistry));

        GoldAccountLedger accountLedger = new GoldAccountLedger(address(memberRegistry));
        console.log("GoldAccountLedger:", address(accountLedger));

        GoldAssetToken goldAssetToken = new GoldAssetToken(
            address(memberRegistry),
            address(accountLedger)
        );
        console.log("GoldAssetToken:", address(goldAssetToken));

        VaultSiteRegistry vaultSiteRegistry = new VaultSiteRegistry(address(memberRegistry));
        console.log("VaultSiteRegistry:", address(vaultSiteRegistry));

        VaultRegistry vaultRegistry = new VaultRegistry(
        address(memberRegistry),
        address(vaultSiteRegistry)
        );
        console.log("VaultRegistry:", address(vaultRegistry));


        vm.stopBroadcast();
    }
}
