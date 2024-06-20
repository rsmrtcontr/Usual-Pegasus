// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IUsd0} from "src/interfaces/token/IUsd0.sol";
import {CheckAccessControl} from "src/utils/CheckAccessControl.sol";
import {IRegistryAccess} from "src/interfaces/registry/IRegistryAccess.sol";
import {IRegistryContract} from "src/interfaces/registry/IRegistryContract.sol";
import {
    CONTRACT_REGISTRY_ACCESS, DEFAULT_ADMIN_ROLE, USD0_MINT, USD0_BURN
} from "src/constants.sol";
import {AmountIsZero, NullContract, NullAddress, Blacklisted, SameValue} from "src/errors.sol";
import {ERC20PausableUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";

/// @title   Usd0 contract
/// @notice  Manages the USD0 token, including minting, burning, and transfers with blacklist checks.
/// @dev     Implements IUsd0 for USD0-specific logic.
/// @author  Usual Tech team
contract Usd0 is ERC20PausableUpgradeable, ERC20PermitUpgradeable, IUsd0 {
    using CheckAccessControl for IRegistryAccess;
    using SafeERC20 for ERC20;

    event Blacklist(address account);
    event UnBlacklist(address account);

    /// @custom:storage-location erc7201:Usd0.storage.v0
    struct Usd0StorageV0 {
        IRegistryAccess registryAccess;
        mapping(address => bool) isBlacklisted;
    }

    // keccak256(abi.encode(uint256(keccak256("Usd0.storage.v0")) - 1)) & ~bytes32(uint256(0xff))
    // solhint-disable-next-line
    bytes32 public constant Usd0StorageV0Location =
        0x1d0cf51e4a8c83492710be318ea33bb77810af742c934c6b56e7b0fecb07db00;

    /// @notice Returns the storage struct of the contract.
    /// @return $ .
    function _usd0StorageV0() internal pure returns (Usd0StorageV0 storage $) {
        bytes32 position = Usd0StorageV0Location;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := position
        }
    }
    /// @custom:oz-upgrades-unsafe-allow constructor

    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                             INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice  Initializes the contract with a registry contract, name, and symbol.
    /// @param   registryContract_ Address of the registry contract for role management.
    /// @param   name_ The name of the USD0 token.
    /// @param   symbol_ The symbol of the USD0 token.
    function initialize(address registryContract_, string memory name_, string memory symbol_)
        public
        initializer
    {
        // Initialize the contract with token details.
        __ERC20_init_unchained(name_, symbol_);
        // Initialize the contract in an unpaused state.
        __Pausable_init_unchained();
        // Initialize the contract with permit functionality.
        __ERC20Permit_init_unchained(name_);
        // Initialize the contract with EIP712 functionality.
        __EIP712_init_unchained(name_, "1");
        // Initialize the contract with the registry contract.
        if (registryContract_ == address(0)) {
            revert NullContract();
        }
        _usd0StorageV0().registryAccess = IRegistryAccess(
            IRegistryContract(registryContract_).getContract(CONTRACT_REGISTRY_ACCESS)
        );
    }
    /*//////////////////////////////////////////////////////////////
                               External
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses all token transfers.
    /// @dev Can only be called by the admin.
    function pause() external {
        Usd0StorageV0 storage $ = _usd0StorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);
        _pause();
    }

    /// @notice Unpauses all token transfers.
    /// @dev Can only be called by the admin.
    function unpause() external {
        Usd0StorageV0 storage $ = _usd0StorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);
        _unpause();
    }

    /// @notice Transfer method
    /// @dev    Callable only when the contract is not paused
    /// @param  to   address of the account who want to receive the token
    /// @param  amount  the amount of token you want to transfer
    /// @return bool .
    function transfer(address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    /// @notice  TransferFrom method
    /// @dev     Callable only when the contract is not paused
    /// @param   sender  address of the account who want to send the token
    /// @param   to  address of the account who want to receive the token
    /// @param   amount  the amount of token you want to transfer
    /// @return  bool  .
    function transferFrom(address sender, address to, uint256 amount)
        public
        override(ERC20Upgradeable, IERC20)
        returns (bool)
    {
        return super.transferFrom(sender, to, amount);
    }

    /// @inheritdoc IUsd0
    function mint(address to, uint256 amount) public {
        if (amount == 0) {
            revert AmountIsZero();
        }

        Usd0StorageV0 storage $ = _usd0StorageV0();
        $.registryAccess.onlyMatchingRole(USD0_MINT);
        _mint(to, amount);
    }

    /// @inheritdoc IUsd0
    function burnFrom(address account, uint256 amount) public {
        Usd0StorageV0 storage $ = _usd0StorageV0();
        //  Ensures the caller has the USD0_BURN role.
        $.registryAccess.onlyMatchingRole(USD0_BURN);
        _burn(account, amount);
    }

    /// @inheritdoc IUsd0
    function burn(uint256 amount) public {
        Usd0StorageV0 storage $ = _usd0StorageV0();

        //  Ensures the caller has the USD0_BURN role.
        $.registryAccess.onlyMatchingRole(USD0_BURN);
        _burn(msg.sender, amount);
    }

    /// @notice Hook that ensures token transfers are not made from or to not blacklisted addresses.
    /// @param from The address sending the tokens.
    /// @param to The address receiving the tokens.
    /// @param amount The amount of tokens being transferred.
    function _update(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20PausableUpgradeable, ERC20Upgradeable)
    {
        Usd0StorageV0 storage $ = _usd0StorageV0();
        if ($.isBlacklisted[from] || $.isBlacklisted[to]) {
            revert Blacklisted();
        }
        super._update(from, to, amount);
    }

    /// @notice  Adds an address to the blacklist.
    /// @dev     Can only be called by the admin.
    /// @param   account  The address to be blacklisted.
    function blacklist(address account) external {
        if (account == address(0)) {
            revert NullAddress();
        }
        Usd0StorageV0 storage $ = _usd0StorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);
        if ($.isBlacklisted[account]) {
            revert SameValue();
        }
        $.isBlacklisted[account] = true;

        emit Blacklist(account);
    }

    /// @notice  Removes an address from the blacklist.
    /// @dev     Can only be called by the admin.
    /// @param   account  The address to be removed from the blacklist.
    function unBlacklist(address account) external {
        Usd0StorageV0 storage $ = _usd0StorageV0();
        $.registryAccess.onlyMatchingRole(DEFAULT_ADMIN_ROLE);
        if (!$.isBlacklisted[account]) {
            revert SameValue();
        }
        $.isBlacklisted[account] = false;

        emit UnBlacklist(account);
    }

    /// @inheritdoc IUsd0
    function isBlacklisted(address account) external view returns (bool) {
        Usd0StorageV0 storage $ = _usd0StorageV0();
        return $.isBlacklisted[account];
    }
}
