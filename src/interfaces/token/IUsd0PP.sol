// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IUsd0PP is IERC20Metadata {
    /// @notice Calculates the number of seconds from beginning to end of the bond period.
    /// @return The number of seconds.
    function totalBondTimes() external view returns (uint256);

    /// @notice get the start time
    /// @dev Used to determine if the bond can be minted.
    /// @return The block timestamp marking the bond starts.
    function getStartTime() external view returns (uint256);

    /// @notice get the end time
    /// @dev Used to determine if the bond can be unwrapped.
    /// @return The block timestamp marking the bond ends.
    function getEndTime() external view returns (uint256);

    /// @notice Mints Usd0PP tokens representing bonds.
    /// @dev Transfers collateral USD0 tokens and mints Usd0PP bonds.
    /// @param amountUsd0 The amount of Usd0 to mint bonds for.
    function mint(uint256 amountUsd0) external;

    /// @notice Mints Usd0PP tokens representing bonds with permit.
    /// @dev    Transfers collateral Usd0PP tokens and mints Usd0PP bonds.
    /// @param  amountUsd0 The amount of Usd0 to mint bonds for.
    /// @param  deadline The deadline for the permit.
    /// @param  v The v value for the permit.
    /// @param  r The r value for the permit.
    /// @param  s The s value for the permit.
    function mintWithPermit(uint256 amountUsd0, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    /// @notice Unwraps the bond after maturity, returning the collateral token.
    /// @dev Only the balance of the caller is unwrapped.
    /// @dev Burns bond tokens and transfers collateral back to the user.
    function unwrap() external;
}
