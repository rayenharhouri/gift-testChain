// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IMemberRegistry {
    function isMemberInRole(address member, uint256 role) external view returns (bool);
    function getMemberStatus(string memory memberGIC) external view returns (uint8);
}

contract GoldAccountLedger is Ownable {
    
    uint256 constant ROLE_PLATFORM = 1 << 6;
    uint256 constant ROLE_CUSTODIAN = 1 << 2;

    struct Account {
        string igan;
        string memberGIC;
        address ownerAddress;
        uint256 balance;
        uint256 createdAt;
        bool active;
    }

    IMemberRegistry public memberRegistry;
    uint256 private _accountCounter;
    
    mapping(string => Account) public accounts;
    mapping(string => string[]) public memberAccounts;
    mapping(address => string[]) public addressAccounts;

    event AccountCreated(
        string indexed igan,
        string indexed memberGIC,
        address indexed ownerAddress,
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

    modifier onlyPlatform() {
        require(memberRegistry.isMemberInRole(msg.sender, ROLE_PLATFORM), "Not authorized: PLATFORM role required");
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

    constructor(address _memberRegistry) Ownable(msg.sender) {
        memberRegistry = IMemberRegistry(_memberRegistry);
        _accountCounter = 1000;
    }

    function createAccount(string memory memberGIC, address ownerAddress) 
        external onlyPlatform returns (string memory) {
        require(bytes(memberGIC).length > 0, "Invalid memberGIC");
        require(ownerAddress != address(0), "Invalid address");

        string memory igan = string(abi.encodePacked("IGAN-", _uint2str(_accountCounter)));
        _accountCounter++;

        Account memory newAccount = Account({
            igan: igan,
            memberGIC: memberGIC,
            ownerAddress: ownerAddress,
            balance: 0,
            createdAt: block.timestamp,
            active: true
        });

        accounts[igan] = newAccount;
        memberAccounts[memberGIC].push(igan);
        addressAccounts[ownerAddress].push(igan);

        emit AccountCreated(igan, memberGIC, ownerAddress, block.timestamp);
        return igan;
    }

    function updateBalance(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) external onlyAuthorized {
        require(accounts[igan].active, "Account not active");
        
        if (delta < 0) {
            require(accounts[igan].balance >= uint256(-delta), "Insufficient balance");
            accounts[igan].balance -= uint256(-delta);
        } else {
            accounts[igan].balance += uint256(delta);
        }

        emit BalanceUpdated(igan, delta, accounts[igan].balance, reason, tokenId, block.timestamp);
    }

    function getAccountBalance(string memory igan) external view returns (uint256) {
        return accounts[igan].balance;
    }

    function getAccountsByMember(string memory memberGIC) external view returns (string[] memory) {
        return memberAccounts[memberGIC];
    }

    function getAccountsByAddress(address addr) external view returns (string[] memory) {
        return addressAccounts[addr];
    }

    function getAccountDetails(string memory igan) external view returns (Account memory) {
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
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
