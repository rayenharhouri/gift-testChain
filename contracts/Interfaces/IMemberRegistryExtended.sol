// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMemberRegistry} from "./IMemberRegistry.sol";

interface IMemberRegistryExtended is IMemberRegistry {
    function addressToMemberGIC(
        address account
    ) external view returns (string memory);

    function addressToUserId(
        address account
    ) external view returns (string memory);
}
