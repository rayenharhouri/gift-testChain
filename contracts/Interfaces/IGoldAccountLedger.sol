// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGoldAccountLedger {
    function updateBalance(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) external;

    function updateBalanceFromContract(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) external;
}
