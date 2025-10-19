// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CollateralManager
/// @notice Manages ERC20 collateral backing for zkERC20 tokens
/// @dev Only authorized zkERC20 contracts can lock/release collateral
contract CollateralManager is ICollateralManager, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    /// @notice Price oracle for token valuations
    IPriceOracle public priceOracle;

    /// @notice Mapping of zkERC20 token => underlying ERC20 token
    mapping(address => address) public underlyingTokens;

    /// @notice Mapping of zkERC20 token => total collateral locked
    mapping(address => uint256) public totalCollateral;

    /// @notice Mapping of authorized zkERC20 tokens
    mapping(address => bool) public authorizedZkTokens;

    // ============ Events ============

    event ZkTokenRegistered(address indexed zkToken, address indexed underlyingToken);
    event ZkTokenAuthorized(address indexed zkToken, bool authorized);
    event PriceOracleUpdated(address indexed oldOracle, address indexed newOracle);

    // ============ Errors ============

    error UnauthorizedZkToken();
    error ZkTokenAlreadyRegistered();
    error ZkTokenNotRegistered();
    error InsufficientCollateral();
    error InvalidAddress();
    error TransferFailed();

    // ============ Constructor ============

    /// @notice Initialize CollateralManager with optional price oracle
    /// @param _priceOracle Address of price oracle (can be zero initially)
    constructor(address _priceOracle) Ownable(msg.sender) {
        if (_priceOracle != address(0)) {
            priceOracle = IPriceOracle(_priceOracle);
        }
    }

    // ============ Admin Functions ============

    /// @notice Register a new zkERC20 token with its underlying collateral token
    /// @param zkToken The zkERC20 token address
    /// @param underlyingToken The ERC20 token used as collateral
    function registerZkToken(address zkToken, address underlyingToken) external override onlyOwner {
        if (zkToken == address(0) || underlyingToken == address(0)) {
            revert InvalidAddress();
        }
        if (underlyingTokens[zkToken] != address(0)) {
            revert ZkTokenAlreadyRegistered();
        }

        underlyingTokens[zkToken] = underlyingToken;
        authorizedZkTokens[zkToken] = true;

        emit ZkTokenRegistered(zkToken, underlyingToken);
        emit ZkTokenAuthorized(zkToken, true);
    }

    /// @notice Authorize or deauthorize a zkERC20 token
    /// @param zkToken The zkERC20 token address
    /// @param authorized Whether to authorize or deauthorize
    function setAuthorization(address zkToken, bool authorized) external onlyOwner {
        if (underlyingTokens[zkToken] == address(0)) {
            revert ZkTokenNotRegistered();
        }

        authorizedZkTokens[zkToken] = authorized;
        emit ZkTokenAuthorized(zkToken, authorized);
    }

    /// @notice Update the price oracle
    /// @param _priceOracle New price oracle address
    function setPriceOracle(address _priceOracle) external onlyOwner {
        address oldOracle = address(priceOracle);
        priceOracle = IPriceOracle(_priceOracle);
        emit PriceOracleUpdated(oldOracle, _priceOracle);
    }

    // ============ Collateral Management ============

    /// @notice Lock ERC20 collateral to mint zkERC20 notes
    /// @param zkToken The zkERC20 token address
    /// @param amount The amount of collateral to lock
    /// @param commitment The commitment for the new note
    /// @return success True if collateral was locked
    function lockCollateral(
        address zkToken,
        uint256 amount,
        bytes32 commitment
    ) external override nonReentrant returns (bool success) {
        // Only authorized zkERC20 contracts can call this
        if (!authorizedZkTokens[zkToken]) {
            revert UnauthorizedZkToken();
        }
        if (msg.sender != zkToken) {
            revert UnauthorizedZkToken();
        }

        address underlyingToken = underlyingTokens[zkToken];
        if (underlyingToken == address(0)) {
            revert ZkTokenNotRegistered();
        }

        // Transfer collateral from zkToken contract to this contract
        // zkToken should have already received the collateral from the user
        IERC20(underlyingToken).safeTransferFrom(msg.sender, address(this), amount);

        // Update total collateral
        totalCollateral[zkToken] += amount;

        emit CollateralLocked(commitment);

        return true;
    }

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
    ) external override nonReentrant returns (bool success) {
        // Only authorized zkERC20 contracts can call this
        if (!authorizedZkTokens[zkToken]) {
            revert UnauthorizedZkToken();
        }
        if (msg.sender != zkToken) {
            revert UnauthorizedZkToken();
        }

        address underlyingToken = underlyingTokens[zkToken];
        if (underlyingToken == address(0)) {
            revert ZkTokenNotRegistered();
        }

        // Check sufficient collateral
        if (totalCollateral[zkToken] < amount) {
            revert InsufficientCollateral();
        }

        // Update total collateral
        totalCollateral[zkToken] -= amount;

        // Transfer collateral to recipient
        IERC20(underlyingToken).safeTransfer(recipient, amount);

        emit CollateralReleased(nullifier);

        return true;
    }

    // ============ View Functions ============

    /// @notice Get the underlying ERC20 token for a zkERC20
    /// @param zkToken The zkERC20 token address
    /// @return token The underlying ERC20 token address
    function getUnderlyingToken(address zkToken) external view override returns (address token) {
        return underlyingTokens[zkToken];
    }

    /// @notice Get total collateral locked for a zkERC20 token
    /// @param zkToken The zkERC20 token address
    /// @return amount Total collateral locked
    function getTotalCollateral(address zkToken) external view override returns (uint256 amount) {
        return totalCollateral[zkToken];
    }

    /// @notice Check if a zkERC20 token is authorized
    /// @param zkToken The zkERC20 token address
    /// @return authorized True if authorized
    function isAuthorized(address zkToken) external view returns (bool authorized) {
        return authorizedZkTokens[zkToken];
    }

    /// @notice Get the current price of underlying token in USD
    /// @param zkToken The zkERC20 token address
    /// @param decimals Desired decimal places for the price
    /// @return priceInUsd The current price in USD with specified decimals
    function getUnderlyingTokenPrice(address zkToken, uint8 decimals) external view returns (uint256 priceInUsd) {
        // Check price oracle first (system-level requirement)
        if (address(priceOracle) == address(0)) {
            revert InvalidAddress();
        }

        address underlyingToken = underlyingTokens[zkToken];
        if (underlyingToken == address(0)) {
            revert ZkTokenNotRegistered();
        }

        return priceOracle.getPriceInUsd(underlyingToken, decimals);
    }

    /// @notice Get the total collateral value in USD
    /// @param zkToken The zkERC20 token address
    /// @param decimals Desired decimal places for the value
    /// @return valueInUsd The total collateral value in USD
    function getTotalCollateralValue(address zkToken, uint8 decimals) external view returns (uint256 valueInUsd) {
        address underlyingToken = underlyingTokens[zkToken];
        if (underlyingToken == address(0)) {
            revert ZkTokenNotRegistered();
        }
        if (address(priceOracle) == address(0)) {
            revert InvalidAddress();
        }

        uint256 collateralAmount = totalCollateral[zkToken];
        if (collateralAmount == 0) {
            return 0;
        }

        uint256 pricePerToken = priceOracle.getPriceInUsd(underlyingToken, decimals);

        // Get the actual decimals of the underlying token
        uint8 tokenDecimals = IERC20Metadata(underlyingToken).decimals();

        // Calculate value: (collateralAmount * pricePerToken) / 10^tokenDecimals
        // collateralAmount is in token's native decimals
        // pricePerToken is in USD with `decimals` decimal places
        // Result is in USD with `decimals` decimal places
        return (collateralAmount * pricePerToken) / (10 ** tokenDecimals);
    }

    /// @notice Get the price oracle address
    /// @return oracle The price oracle address
    function getPriceOracle() external view returns (address oracle) {
        return address(priceOracle);
    }
}
