// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IMemberRegistry} from "./Interfaces/IMemberRegistry.sol";

/**
 * @title GoldAccountLedger
 * @dev On-chain ledger for "gold accounts" (IGAN) owned by GIFT members.
 *
 * Responsibilities:
 * - Create and register gold accounts for active members
 * - Maintain per-account gold balance (units/tokens)
 * - Provide controlled balance mutation via:
 *   - PLATFORM / CUSTODIAN (admin path)
 *   - Whitelisted contracts (system path)
 *
 * Design notes:
 * - Accounts are keyed by `igan` (string) to stay aligned with off-chain IDs.
 * - Member validity is delegated to `IMemberRegistry`.
 * - This contract does NOT custody ERC20/ETH; it only maintains a ledger.
 */
contract GoldAccountLedger is Ownable {
    // -------------------------------------------------------------------------
    // Constants & Types
    // -------------------------------------------------------------------------

    /// @notice Bitmask for the PLATFORM role in the member registry.
    uint256 public constant ROLE_PLATFORM = 1 << 6;

    /// @notice Bitmask for the CUSTODIAN role in the member registry.
    uint256 public constant ROLE_CUSTODIAN = 1 << 2;

    /// @notice Member status value indicating an active member in IMemberRegistry.
    uint8 public constant MEMBER_ACTIVE = 1;

    /**
     * @notice Gold account metadata and state.
     * @dev `balance` is the on-chain gold balance (atomic units).
     *      `initialDeposit` is a fiat/off-chain value mirrored for reference.
     */
    struct Account {
        /// @notice IGAN (gold account identifier) — external/business ID.
        string igan;
        /// @notice GIC of the member that owns this account.
        string memberGIC;
        /// @notice EOA or contract address that operates this account.
        address ownerAddress;
        /// @notice Vault site identifier where the underlying gold is stored.
        string vaultSiteId;
        /// @notice Off-chain/fiat guarantee deposit account reference.
        string guaranteeDepositAccount;
        /// @notice Account purpose, e.g. 'trading', 'custody', 'collateral', 'savings'.
        string goldAccountPurpose;
        /// @notice Initial deposit value (fiat/off-chain) for reference only.
        uint256 initialDeposit;
        /// @notice Reason for absence of certificate, if applicable.
        string certificateAbsenceReason;
        /// @notice On-chain gold balance (units/tokens).
        uint256 balance;
        /// @notice UNIX timestamp of account creation.
        uint256 createdAt;
        /// @notice Whether the account is currently active.
        bool active;
    }

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    /// @notice Registry used to check member roles and statuses.
    IMemberRegistry public memberRegistry;

    /// @dev Reserved counter for potential auto-IGAN generation (currently unused).
    uint256 private _accountCounter;

    /// @notice Mapping from IGAN to account details.
    mapping(string => Account) public accounts;

    /// @notice Mapping from member GIC to list of IGANs they own.
    mapping(string => string[]) public memberAccounts;

    /// @notice Mapping from owner address to list of IGANs controlled by that address.
    mapping(address => string[]) public addressAccounts;

    /**
     * @notice Whitelisted contracts allowed to update balances via `updateBalanceFromContract`.
     * @dev Set by PLATFORM via `setBalanceUpdater`.
     */
    mapping(address => bool) public balanceUpdaters;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    /// @dev Restricts a function to addresses with PLATFORM role in `memberRegistry`.
    modifier onlyPlatform() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_PLATFORM),
            "Not authorized: PLATFORM role required"
        );
        _;
    }

    /// @dev Restricts a function to addresses with PLATFORM or CUSTODIAN roles.
    modifier onlyAuthorized() {
        require(
            memberRegistry.isMemberInRole(msg.sender, ROLE_PLATFORM) ||
                memberRegistry.isMemberInRole(msg.sender, ROLE_CUSTODIAN),
            "Not authorized"
        );
        _;
    }

    /// @dev Restricts a function to addresses whitelisted as balance updaters.
    modifier onlyBalanceUpdater() {
        require(balanceUpdaters[msg.sender], "Not authorized: updater");
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @notice Deploys the GoldAccountLedger.
     * @param _memberRegistry Address of the IMemberRegistry contract to integrate with.
     */
    constructor(address _memberRegistry) Ownable(msg.sender) {
        require(_memberRegistry != address(0), "Invalid registry");
        memberRegistry = IMemberRegistry(_memberRegistry);

        // Optional: reserved for future auto-IGAN generation if needed.
        _accountCounter = 1000;
    }

    // -------------------------------------------------------------------------
    // Admin / Configuration
    // -------------------------------------------------------------------------

    /**
     * @notice Grants or revokes permission for an address to update balances via `updateBalanceFromContract`.
     * @dev Callable only by PLATFORM. Intended for system contracts like GoldAssetToken.
     *
     * @param updater Address of the contract (or EOA) to update.
     * @param allowed Whether the address is allowed to call `updateBalanceFromContract`.
     */
    function setBalanceUpdater(
        address updater,
        bool allowed
    ) external onlyPlatform {
        require(updater != address(0), "Invalid updater");
        balanceUpdaters[updater] = allowed;
        emit BalanceUpdaterSet(updater, allowed, block.timestamp);
    }

    // -------------------------------------------------------------------------
    // Account Management
    // -------------------------------------------------------------------------

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
        // Basic required fields
        require(bytes(igan).length > 0, "Invalid IGAN");
        require(bytes(memberGIC).length > 0, "Invalid memberGIC");
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

        // Member must be active
        uint8 status = memberRegistry.getMemberStatus(memberGIC);
        require(status == MEMBER_ACTIVE, "Member not active");

        // IGAN must not be in use
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
            balance: 0,
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

    // -------------------------------------------------------------------------
    // Balance Management
    // -------------------------------------------------------------------------

    /**
     * @notice Adjusts an account balance (admin / human path).
     * @dev
     * - Callable by PLATFORM or CUSTODIAN.
     * - `delta` can be positive (credit) or negative (debit).
     * - Reverts if resulting balance would be negative.
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
     * @notice Adjusts an account balance from a whitelisted contract (system path).
     * @dev
     * - Caller must be marked as `balanceUpdaters[caller] == true`.
     * - Intended for programmatic flows (e.g., asset lifecycle).
     */
    function updateBalanceFromContract(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) external onlyBalanceUpdater {
        _updateBalanceInternal(igan, delta, reason, tokenId);
    }

    /**
     * @dev Internal balance update routine used by both public entrypoints.
     */
    function _updateBalanceInternal(
        string memory igan,
        int256 delta,
        string memory reason,
        uint256 tokenId
    ) internal {
        Account storage account = accounts[igan];

        require(account.createdAt != 0, "Account does not exist");
        require(account.active, "Account not active");

        if (delta < 0) {
            uint256 absDelta = uint256(-delta);
            require(account.balance >= absDelta, "Insufficient balance");
            account.balance -= absDelta;
        } else if (delta > 0) {
            account.balance += uint256(delta);
        } else {
            // delta == 0 allowed (no-op)
        }

        emit BalanceUpdated(
            igan,
            delta,
            account.balance,
            reason,
            tokenId,
            block.timestamp
        );
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function getAccountBalance(
        string memory igan
    ) external view returns (uint256 balance) {
        require(accounts[igan].createdAt != 0, "Account does not exist");
        return accounts[igan].balance;
    }

    function getAccountsByMember(
        string memory memberGIC
    ) external view returns (string[] memory list) {
        return memberAccounts[memberGIC];
    }

    function getAccountsByAddress(
        address addr
    ) external view returns (string[] memory list) {
        return addressAccounts[addr];
    }

    function getAccountDetails(
        string memory igan
    ) external view returns (Account memory account) {
        require(accounts[igan].createdAt != 0, "Account does not exist");
        return accounts[igan];
    }

    // -------------------------------------------------------------------------
    // Internal helpers (reserved / legacy)
    // -------------------------------------------------------------------------

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
            uint8 temp = 48 + uint8(_i - (_i / 10) * 10);
            bstr[k] = bytes1(temp);
            _i /= 10;
        }
        return string(bstr);
    }
}
