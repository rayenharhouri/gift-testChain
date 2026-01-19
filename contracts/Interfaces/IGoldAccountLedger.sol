// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGoldAccountLedger {
    struct Account {
        string igan;
        string memberGIC;
        address ownerAddress;
        string vaultSiteId;
        string guaranteeDepositAccount;
        string goldAccountPurpose;
        uint256 initialDeposit;
        string certificateAbsenceReason;
        uint256 balance;
        uint256 createdAt;
        bool active;
    }

    function getAccountDetails(
        string memory igan
    ) external view returns (Account memory account);

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
