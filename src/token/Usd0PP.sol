// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PausableUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {IUsd0PP} from "src/interfaces/token/IUsd0PP.sol";
import {IUsd0} from "./../interfaces/token/IUsd0.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Permit.sol";
import {CheckAccessControl} from "src/utils/CheckAccessControl.sol";

import {
    CONTRACT_REGISTRY_ACCESS,
    DEFAULT_ADMIN_ROLE,
    CONTRACT_USD0,
    BOND_DURATION_FOUR_YEAR
} from "src/constants.sol";

import {
    BondNotStarted,
    BondFinished,
    BondNotFinished,
    NotAuthorized,
    AmountIsZero,
    InvalidName,
    InvalidSymbol,
    BeginInPast,
    Blacklisted
} from "src/errors.sol";

/// @title   Usd0PP Contract
/// @notice  Manages bond-like financial instruments for the UsualDAO ecosystem, providing functionality for minting, transferring, and unwrapping bonds.
/// @dev     Inherits from ERC20, ERC20PermitUpgradeable, and ReentrancyGuardUpgradeable to provide a range of functionalities along with protections against reentrancy attacks.
/// @dev     This contract is upgradeable, allowing for future improvements and enhancements.
/// @author  Usual Tech team

contract Usd0PP is
    IUsd0PP,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    ReentrancyGuardUpgradeable
{
    using CheckAccessControl for IRegistryAccess;
    using SafeERC20 for IERC20;

    /// @notice Emitted when a bond is unwrapped.
    /// @param user The address of the user unwrapping the bond.
    /// @param amount The amount of the bond unwrapped.
    event BondUnwrapped(address indexed user, uint256 amount);

    /// @notice Emitted when an emergency withdrawal occurs.
    /// @param account The address of the account initiating the emergency withdrawal.
    /// @param balance The balance withdrawn.
    event EmergencyWithdraw(address indexed account, uint256 balance);

    struct Usd0PPStorageV0 {
        /// The start time of the bond period.
        uint256 bondStart;
        /// The address of the registry contract.
        IRegistryContract registryContract;
        /// The address of the registry access contract.
        IRegistryAccess registryAccess;
        /// The USD0 token.
        IERC20 usd0;
    }

    // keccak256(abi.encode(uint256(keccak256("Usd0PP.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant Usd0PPStorageV0Location =
        0x1519c21cc5b6e62f5c0018a7d32a0d00805e5b91f6eaa9f7bc303641242e3000;

    /// @notice Returns the storage struct of the contract.
    /// @return $ .
    function _usd0ppStorageV0() private pure returns (Usd0PPStorageV0 storage $) {
        bytes32 position = Usd0PPStorageV0Location;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := position
        }
    }

    /*//////////////////////////////////////////////////////////////
                             Constructor
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with bond parameters and related registry and token information.
    /// @dev  The end time of the bond period will be four years later.
    /// @param registryContract The address of the registry contract.
    /// @param name_ The name of the bond token.
    /// @param symbol_ The symbol of the bond token.
    /// @param startTime The start time of the bond period.
    // solhint-disable code-complexity
    function initialize(
        address registryContract,
        string memory name_,
        string memory symbol_,
        uint256 startTime
    ) public initializer {
        _createUsd0PPCheck(name_, symbol_, startTime);

        __ERC20_init_unchained(name_, symbol_);
        __ERC20Permit_init_unchained(name_);
        __EIP712_init_unchained(name_, "1");
        __ReentrancyGuard_init_unchained();
        // Create the bond token
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        $.bondStart = startTime;
        $.registryContract = IRegistryContract(registryContract);
        $.usd0 = IERC20(IRegistryContract(registryContract).getContract(CONTRACT_USD0));
        $.registryAccess = IRegistryAccess(
            IRegistryContract(registryContract).getContract(CONTRACT_REGISTRY_ACCESS)
        );
    }

    /// @notice Checks the parameters for creating a bond.
    /// @param name The name of the bond token (cannot be empty)
    /// @param symbol The symbol of the bond token (cannot be empty)
    /// @param startTime The start time of the bond period (must be in the future)
    function _createUsd0PPCheck(string memory name, string memory symbol, uint256 startTime)
        internal
        view
    {
        // Check if the bond start date is after now
        if (startTime < block.timestamp) {
            revert BeginInPast();
        }
        // Check if the name is not empty
        if (bytes(name).length == 0) {
            revert InvalidName();
        }
        // Check if the symbol is not empty
        if (bytes(symbol).length == 0) {
            revert InvalidSymbol();
        }
    }

    /// @notice Pauses all token transfers.
    /// @dev Can only be called by the admin.
    function pause() public {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);
        _pause();
    }

    /// @notice Unpauses all token transfers.
    /// @dev Can only be called by the admin.
    function unpause() external {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);
        _unpause();
    }

    // @inheritdoc IUsd0PP
    function mint(uint256 amountUsd0) public nonReentrant whenNotPaused {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        // revert if the bond period isn't started
        if (block.timestamp < $.bondStart) {
            revert BondNotStarted();
        }
        // revert if the bond period is finished
        if (block.timestamp >= $.bondStart + BOND_DURATION_FOUR_YEAR) {
            revert BondFinished();
        }

        // get the collateral token for the bond
        $.usd0.safeTransferFrom(msg.sender, address(this), amountUsd0);

        // mint the bond for the sender
        _mint(msg.sender, amountUsd0);
    }

    // @inheritdoc IUsd0PP
    function mintWithPermit(uint256 amountUsd0, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        try IERC20Permit(address($.usd0)).permit(
            msg.sender, address(this), amountUsd0, deadline, v, r, s
        ) {} catch {} // solhint-disable-line no-empty-blocks

        mint(amountUsd0);
    }

    function _update(address sender, address recipient, uint256 amount)
        internal
        override(ERC20PausableUpgradeable, ERC20Upgradeable)
    {
        if (amount == 0) {
            revert AmountIsZero();
        }
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        IUsd0 usd0 = IUsd0(address($.usd0));
        if (usd0.isBlacklisted(sender) || usd0.isBlacklisted(recipient)) {
            revert Blacklisted();
        }
        // we update the balance of the sender and the recipient
        super._update(sender, recipient, amount);
    }

    /// @notice Transfers `amount` tokens from the caller to `recipient`.
    /// @param recipient The address to transfer to.
    /// @param amount The amount to be transferred.
    /// @return True if the transfer was successful, otherwise false.
    function transfer(address recipient, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20)
        returns (bool)
    {
        return super.transfer(recipient, amount);
    }

    // @inheritdoc IUsd0PP
    function unwrap() external nonReentrant whenNotPaused {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        // revert if the bond period is not finished
        if (block.timestamp < $.bondStart + BOND_DURATION_FOUR_YEAR) {
            revert BondNotFinished();
        }
        uint256 usd0PPBalance = balanceOf(msg.sender);

        _burn(msg.sender, usd0PPBalance);

        $.usd0.safeTransfer(msg.sender, usd0PPBalance);

        emit BondUnwrapped(msg.sender, usd0PPBalance);
    }

    // @inheritdoc IUsd0PP
    function totalBondTimes() public pure returns (uint256) {
        return BOND_DURATION_FOUR_YEAR;
    }

    // @inheritdoc IUsd0PP
    function getStartTime() external view returns (uint256) {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        return $.bondStart;
    }

    // @inheritdoc IUsd0PP
    function getEndTime() external view returns (uint256) {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();
        return $.bondStart + BOND_DURATION_FOUR_YEAR;
    }

    /// @notice function for executing the emergency withdrawal of Usd0.
    /// @param  safeAccount The address of the account to withdraw the Usd0 to.
    /// @dev    Reverts if the caller does not have the DEFAULT_ADMIN_ROLE role.
    function emergencyWithdraw(address safeAccount) external {
        Usd0PPStorageV0 storage $ = _usd0ppStorageV0();

        if (!$.registryAccess.hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotAuthorized();
        }
        IERC20 usd0 = $.usd0;

        uint256 balance = usd0.balanceOf(address(this));
        // get the collateral token for the bond
        usd0.safeTransfer(safeAccount, balance);

        // Pause the contract
        _pause();

        emit EmergencyWithdraw(safeAccount, balance);
    }

    /// @notice Transfers `amount` tokens from `sender` to `recipient`.
    /// @param sender The address to transfer from.
    /// @param recipient The address to transfer to.
    /// @param amount The amount to be transferred.
    /// @return True if the transfer was successful, otherwise false.
    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20)
        returns (bool)
    {
        return super.transferFrom(sender, recipient, amount);
    }
}
