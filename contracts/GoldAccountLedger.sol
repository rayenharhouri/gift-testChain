// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Interfaces/IMemberRegistry.sol";

contract GoldAccountLedger is Ownable {
    uint256 constant ROLE_PLATFORM = 1 << 6;
    uint256 constant ROLE_CUSTODIAN = 1 << 2;
    uint8 constant MEMBER_ACTIVE = 1;

    struct Account {
        string igan;
        string memberGIC; // owner member
        address ownerAddress; // wallet that operates the account
        string vaultSiteId; // vault_site_id
        string guaranteeDepositAccount; // guarantee_deposit_account
        string goldAccountPurpose; // gold_account_purpose: 'trading', 'custody', 'collateral', 'savings'
        uint256 initialDeposit; // initial_deposit (fiat/off-chain amount, just stored)
        string certificateAbsenceReason; // certificate_absence_reason
        uint256 balance; // gold balance (tokens/units)
        uint256 createdAt;
        bool active;
    }

    IMemberRegistry public memberRegistry;
    uint256 private _accountCounter;

    mapping(string => Account) public accounts;
    mapping(string => string[]) public memberAccounts;
    mapping(address => string[]) public addressAccounts;

    // US-10 prep: only validated contracts can adjust balances
    mapping(address => bool) public balanceUpdaters;

    event AccountCreated(
        string indexed igan,
        string indexed memberGIC,
        address indexed ownerAddress,
        string vaultSiteId,
        string guaranteeDepositAccount,
        string goldAccountPurpose,
        uint256 initialDeposit,
        string certificateAbsenceReason,
        uint256 timestamp
    );

    event BalanceUpdated(
        string indexed igan,
        int256 delta,
        uint256 newBalance,
        string reason,
        uint256 tokenId,
        uint256 timestamp
    );

    event BalanceUpdaterSet(
        address indexed updater,
        bool allowed,
        uint256 timestamp
    );

    modifier onlyPlatform() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_PLATFORM),
            "Not authorized: PLATFORM role required"
        );
        _;
    }

    modifier onlyAuthorized() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_PLATFORM) ||
                memberRegistry.isMemberInRole(msg.sender, ROLE_CUSTODIAN),
            "Not authorized"
        );
        _;
    }

    modifier onlyBalanceUpdater() {
        require(balanceUpdaters[msg.sender], "Not authorized: updater");
        _;
    }

    constructor(address _memberRegistry) Ownable(msg.sender) {
        memberRegistry = IMemberRegistry(_memberRegistry);
        _accountCounter = 1000;
    }

    /**
     * @dev Allow PLATFORM to approve which contracts can call updateBalanceFromContract()
     */
    function setBalanceUpdater(
        address updater,
        bool allowed
    ) external onlyPlatform {
        require(updater != address(0), "Invalid updater");
        balanceUpdaters[updater] = allowed;
        emit BalanceUpdaterSet(updater, allowed, block.timestamp);
    }

    function createAccount(
        string memory igan,
        string memory memberGIC,
        string memory vaultSiteId,
        string memory guaranteeDepositAccount,
        string memory goldAccountPurpose,
        uint256 initialDeposit,
        string memory certificateAbsenceReason,
        address ownerAddress
    ) external onlyPlatform returns (string memory) {
        require(bytes(igan).length > 0, "Invalid IGAN");
        require(bytes(memberGIC).length > 0, "Invalid memberGIC");
        uint8 status = memberRegistry.getMemberStatus(memberGIC);
        require(status == MEMBER_ACTIVE, "Member not active");
        require(bytes(vaultSiteId).length > 0, "Invalid vault site");
        require(
            bytes(guaranteeDepositAccount).length > 0,
            "Invalid guarantee deposit account"
        );
        require(
            bytes(goldAccountPurpose).length > 0,
            "Invalid account purpose"
        );
        require(ownerAddress != address(0), "Invalid address");
        require(accounts[igan].createdAt == 0, "Account already exists");

        Account memory newAccount = Account({
            igan: igan,
            memberGIC: memberGIC,
            ownerAddress: ownerAddress,
            vaultSiteId: vaultSiteId,
            guaranteeDepositAccount: guaranteeDepositAccount,
            goldAccountPurpose: goldAccountPurpose,
            initialDeposit: initialDeposit,
            certificateAbsenceReason: certificateAbsenceReason,
            balance: 0, // gold balance starts at 0
            createdAt: block.timestamp,
            active: true
        });

        accounts[igan] = newAccount;
        memberAccounts[memberGIC].push(igan);
        addressAccounts[ownerAddress].push(igan);

        emit AccountCreated(
            igan,
            memberGIC,
            ownerAddress,
            vaultSiteId,
            guaranteeDepositAccount,
            goldAccountPurpose,
            initialDeposit,
            certificateAbsenceReason,
            block.timestamp
        );

        return igan;
    }

    /**
     * @dev MVP/admin path (kept): PLATFORM or CUSTODIAN can adjust balances.
     * For US-10 strict mode, you can later restrict/remove this and use updateBalanceFromContract().
     */
    function updateBalance(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) external onlyAuthorized {
        _updateBalanceInternal(igan, delta, reason, tokenId);
    }

    /**
     * @dev US-10 path: only validated smart contracts can adjust balances
     */
    function updateBalanceFromContract(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) external onlyBalanceUpdater {
        _updateBalanceInternal(igan, delta, reason, tokenId);
    }

    function _updateBalanceInternal(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) internal {
        // Step 3: clear existence vs active errors
        require(accounts[igan].createdAt != 0, "Account does not exist");
        require(accounts[igan].active, "Account not active");

        if (delta < 0) {
            require(
                accounts[igan].balance >= uint256(-delta),
                "Insufficient balance"
            );
            accounts[igan].balance -= uint256(-delta);
        } else {
            accounts[igan].balance += uint256(delta);
        }

        emit BalanceUpdated(
            igan,
            delta,
            accounts[igan].balance,
            reason,
            tokenId,
            block.timestamp
        );
    }

    function getAccountBalance(
        string memory igan
    ) external view returns (uint256) {
        require(accounts[igan].createdAt != 0, "Account does not exist");
        return accounts[igan].balance;
    }

    function getAccountsByMember(
        string memory memberGIC
    ) external view returns (string[] memory) {
        return memberAccounts[memberGIC];
    }

    function getAccountsByAddress(
        address addr
    ) external view returns (string[] memory) {
        return addressAccounts[addr];
    }

    function getAccountDetails(
        string memory igan
    ) external view returns (Account memory) {
        require(accounts[igan].createdAt != 0, "Account does not exist");
        return accounts[igan];
    }

    function _uint2str(uint256 _i) private pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bstr[k] = bytes1(temp);
            _i /= 10;
        }
        return string(bstr);
    }
}
