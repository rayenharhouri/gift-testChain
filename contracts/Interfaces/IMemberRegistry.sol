// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMemberRegistry {
    function isMemberInRole(address member, uint256 role) external view returns (bool);
    function getMemberStatus(string memory memberGIC) external view returns (uint8);
}