// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../contracts/MemberRegistry.sol";
import "../contracts/GoldAssetToken.sol";
import "../contracts/GoldAccountLedger.sol";

contract DeployGIFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MemberRegistry memberRegistry = new MemberRegistry();
        console.log("DEPLOYED_MEMBER_REGISTRY=%s", address(memberRegistry));

        GoldAccountLedger accountLedger = new GoldAccountLedger(address(memberRegistry));
        console.log("DEPLOYED_GOLD_ACCOUNT_LEDGER=%s", address(accountLedger));

        GoldAssetToken goldAssetToken = new GoldAssetToken(address(memberRegistry), address(accountLedger));
        console.log("DEPLOYED_GOLD_ASSET_TOKEN=%s", address(goldAssetToken));

        vm.stopBroadcast();
    }
}
