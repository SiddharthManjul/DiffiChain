// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPriceOracle
/// @notice Interface for price oracle providing token price feeds
interface IPriceOracle {
    // ============ Events ============

    /// @notice Emitted when prices are updated
    /// @param priceIds Array of price feed IDs that were updated
    /// @param updateFee Fee paid for the update
    event PricesUpdated(bytes32[] priceIds, uint256 updateFee);

    /// @notice Emitted when a price feed is registered for a token
    /// @param token Token address
    /// @param priceId Pyth price feed ID
    event PriceFeedRegistered(address indexed token, bytes32 priceId);

    // ============ Structs ============

    /// @notice Price data structure
    /// @param price The price
    /// @param conf The confidence interval
    /// @param expo The exponent
    /// @param publishTime When the price was published
    struct Price {
        int64 price;
        uint64 conf;
        int32 expo;
        uint256 publishTime;
    }

    // ============ Functions ============

    /// @notice Update price feeds with new data from Pyth Network
    /// @param priceUpdateData Encoded price update data from Pyth
    function updatePriceFeeds(bytes[] calldata priceUpdateData) external payable;

    /// @notice Get the current price for a token
    /// @param token The token address
    /// @return price The latest price data
    function getPrice(address token) external view returns (Price memory price);

    /// @notice Get the USD price for a token with specified decimals
    /// @param token The token address
    /// @param decimals Desired decimal places for the price
    /// @return priceInUsd The price in USD with the specified decimals
    function getPriceInUsd(address token, uint8 decimals) external view returns (uint256 priceInUsd);

    /// @notice Get the update fee for updating price feeds
    /// @param priceUpdateData Encoded price update data
    /// @return feeAmount The fee amount in wei
    function getUpdateFee(bytes[] calldata priceUpdateData) external view returns (uint256 feeAmount);

    /// @notice Register a price feed for a token
    /// @param token Token address
    /// @param priceId Pyth Network price feed ID
    function registerPriceFeed(address token, bytes32 priceId) external;

    /// @notice Get the price feed ID for a token
    /// @param token Token address
    /// @return priceId The Pyth price feed ID
    function getPriceFeedId(address token) external view returns (bytes32 priceId);
}
