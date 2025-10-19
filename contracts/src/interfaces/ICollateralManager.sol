// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICollateralManager
/// @notice Interface for managing ERC20 collateral for zkERC20 tokens
interface ICollateralManager {
    /// @notice Emitted when collateral is locked (private - no amounts)
    /// @param commitment The commitment associated with this deposit
    event CollateralLocked(bytes32 indexed commitment);

    /// @notice Emitted when collateral is released (private - no amounts)
    /// @param nullifier The nullifier of the note being redeemed
    event CollateralReleased(bytes32 indexed nullifier);

    /// @notice Lock ERC20 collateral to mint zkERC20 notes
    /// @param zkToken The zkERC20 token address
    /// @param amount The amount of collateral to lock
    /// @param commitment The commitment for the new note
    /// @return success True if collateral was locked
    function lockCollateral(
        address zkToken,
        uint256 amount,
        bytes32 commitment
    ) external returns (bool success);

    /// @notice Release ERC20 collateral when burning zkERC20 notes
    /// @param zkToken The zkERC20 token address
    /// @param recipient The address to receive the released collateral
    /// @param amount The amount of collateral to release
    /// @param nullifier The nullifier of the burned note
    /// @return success True if collateral was released
    function releaseCollateral(
        address zkToken,
        address recipient,
        uint256 amount,
        bytes32 nullifier
    ) external returns (bool success);

    /// @notice Get the underlying ERC20 token for a zkERC20
    /// @param zkToken The zkERC20 token address
    /// @return token The underlying ERC20 token address
    function getUnderlyingToken(address zkToken) external view returns (address token);

    /// @notice Get total collateral locked for a zkERC20 token
    /// @param zkToken The zkERC20 token address
    /// @return amount Total collateral locked
    function getTotalCollateral(address zkToken) external view returns (uint256 amount);

    /// @notice Register a new zkERC20 token with its underlying collateral
    /// @param zkToken The zkERC20 token address
    /// @param underlyingToken The ERC20 token used as collateral
    function registerZkToken(address zkToken, address underlyingToken) external;
}
