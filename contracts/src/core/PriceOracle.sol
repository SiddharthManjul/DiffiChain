// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {IPyth} from "../interfaces/pyth/IPyth.sol";
import {PythStructs} from "../interfaces/pyth/PythStructs.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title PriceOracle
/// @notice Oracle contract integrating Pyth Network for real-time token price feeds
/// @dev Used by CollateralManager and other contracts requiring price data
contract PriceOracle is IPriceOracle, Ownable {
    // ============ State Variables ============

    /// @notice Pyth Network contract
    IPyth public immutable PYTH;

    /// @notice Mapping of token address to Pyth price feed ID
    mapping(address => bytes32) public tokenToPriceFeed;

    /// @notice Mapping of Pyth price feed ID to token address
    mapping(bytes32 => address) public priceFeedToToken;

    /// @notice Maximum age of price data in seconds (default: 60 seconds)
    uint256 public maxPriceAge = 60;

    // ============ Errors ============

    error InvalidPriceUpdate();
    error PriceFeedNotRegistered();
    error PriceFeedAlreadyRegistered();
    error InvalidToken();
    error InvalidPriceId();
    error StalePrice();
    error InsufficientFee();
    error PriceNotPositive();

    // ============ Constructor ============

    /// @notice Initialize the PriceOracle with Pyth Network contract
    /// @param _pyth Address of the Pyth Network contract on this chain
    constructor(address _pyth) Ownable(msg.sender) {
        if (_pyth == address(0)) revert InvalidToken();
        PYTH = IPyth(_pyth);
    }

    // ============ Admin Functions ============

    /// @notice Register a price feed for a token
    /// @param token Token address
    /// @param priceId Pyth Network price feed ID
    function registerPriceFeed(address token, bytes32 priceId) external override onlyOwner {
        if (token == address(0)) revert InvalidToken();
        if (priceId == bytes32(0)) revert InvalidPriceId();
        if (tokenToPriceFeed[token] != bytes32(0)) revert PriceFeedAlreadyRegistered();

        tokenToPriceFeed[token] = priceId;
        priceFeedToToken[priceId] = token;

        emit PriceFeedRegistered(token, priceId);
    }

    /// @notice Set maximum price age
    /// @param _maxPriceAge Maximum age in seconds
    function setMaxPriceAge(uint256 _maxPriceAge) external onlyOwner {
        maxPriceAge = _maxPriceAge;
    }

    // ============ Price Update Functions ============

    /// @notice Update price feeds with new data from Pyth Network
    /// @param priceUpdateData Encoded price update data from Pyth
    function updatePriceFeeds(bytes[] calldata priceUpdateData) external payable override {
        // Get required fee
        uint256 fee = PYTH.getUpdateFee(priceUpdateData);
        if (msg.value < fee) revert InsufficientFee();

        // Update prices on Pyth contract
        PYTH.updatePriceFeeds{value: fee}(priceUpdateData);

        // Emit event with empty price IDs array (since extracting from calldata is complex)
        // Frontend should track which prices were updated
        bytes32[] memory priceIds = new bytes32[](0);
        emit PricesUpdated(priceIds, fee);

        // Refund excess payment
        if (msg.value > fee) {
            (bool success, ) = msg.sender.call{value: msg.value - fee}("");
            require(success, "Refund failed");
        }
    }

    // ============ View Functions ============

    /// @notice Get the current price for a token
    /// @param token The token address
    /// @return price The latest price data
    function getPrice(address token) external view override returns (Price memory price) {
        bytes32 priceId = tokenToPriceFeed[token];
        if (priceId == bytes32(0)) revert PriceFeedNotRegistered();

        PythStructs.Price memory pythPrice = PYTH.getPriceNoOlderThan(priceId, maxPriceAge);

        // Validate price
        if (pythPrice.price <= 0) revert PriceNotPositive();

        price = Price({
            price: pythPrice.price,
            conf: pythPrice.conf,
            expo: pythPrice.expo,
            publishTime: pythPrice.publishTime
        });
    }

    /// @notice Get the USD price for a token with specified decimals
    /// @param token The token address
    /// @param decimals Desired decimal places for the price
    /// @return priceInUsd The price in USD with the specified decimals
    function getPriceInUsd(address token, uint8 decimals) external view override returns (uint256 priceInUsd) {
        bytes32 priceId = tokenToPriceFeed[token];
        if (priceId == bytes32(0)) revert PriceFeedNotRegistered();

        PythStructs.Price memory pythPrice = PYTH.getPriceNoOlderThan(priceId, maxPriceAge);

        // Validate price
        if (pythPrice.price <= 0) revert PriceNotPositive();

        // Convert price to desired decimals
        // Pyth stores price as: price * 10^expo = actual_dollar_value
        // We want: result where result / 10^decimals = actual_dollar_value
        // Therefore: result = actual_dollar_value * 10^decimals = price * 10^expo * 10^decimals = price * 10^(expo+decimals)

        int64 price64 = pythPrice.price;
        int32 expo = pythPrice.expo;
        int32 targetDecimals = int32(uint32(decimals));

        // Calculate adjustment: expo + decimals
        int32 adjustment = expo + targetDecimals;

        if (adjustment >= 0) {
            // Multiply by 10^adjustment
            priceInUsd = uint256(int256(price64)) * (10 ** uint32(adjustment));
        } else {
            // Divide by 10^(-adjustment)
            priceInUsd = uint256(int256(price64)) / (10 ** uint32(-adjustment));
        }
    }

    /// @notice Get the update fee for updating price feeds
    /// @param priceUpdateData Encoded price update data
    /// @return feeAmount The fee amount in wei
    function getUpdateFee(bytes[] calldata priceUpdateData) external view override returns (uint256 feeAmount) {
        return PYTH.getUpdateFee(priceUpdateData);
    }

    /// @notice Get the price feed ID for a token
    /// @param token Token address
    /// @return priceId The Pyth price feed ID
    function getPriceFeedId(address token) external view override returns (bytes32 priceId) {
        priceId = tokenToPriceFeed[token];
        if (priceId == bytes32(0)) revert PriceFeedNotRegistered();
    }

    /// @notice Get the latest price without age check (use with caution)
    /// @param token The token address
    /// @return price The latest price data
    function getPriceUnsafe(address token) external view returns (Price memory price) {
        bytes32 priceId = tokenToPriceFeed[token];
        if (priceId == bytes32(0)) revert PriceFeedNotRegistered();

        PythStructs.Price memory pythPrice = PYTH.getPriceUnsafe(priceId);

        // Validate price (even for unsafe, we validate it's positive)
        if (pythPrice.price <= 0) revert PriceNotPositive();

        price = Price({
            price: pythPrice.price,
            conf: pythPrice.conf,
            expo: pythPrice.expo,
            publishTime: pythPrice.publishTime
        });
    }

    /// @notice Check if a token has a registered price feed
    /// @param token Token address
    /// @return registered True if price feed is registered
    function hasPriceFeed(address token) external view returns (bool registered) {
        return tokenToPriceFeed[token] != bytes32(0);
    }

    /// @notice Get Pyth contract address
    /// @return pythAddress The Pyth contract address
    function getPythContract() external view returns (address pythAddress) {
        return address(PYTH);
    }
}
