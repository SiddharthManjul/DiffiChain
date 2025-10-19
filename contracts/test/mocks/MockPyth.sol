// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPyth} from "../../src/interfaces/pyth/IPyth.sol";
import {PythStructs} from "../../src/interfaces/pyth/PythStructs.sol";

/// @title MockPyth
/// @notice Mock Pyth contract for testing
contract MockPyth is IPyth {
    mapping(bytes32 => PythStructs.Price) public prices;
    uint256 public updateFee = 1 wei;

    function setPrice(bytes32 id, int64 price, uint64 conf, int32 expo, uint256 publishTime) external {
        prices[id] = PythStructs.Price({price: price, conf: conf, expo: expo, publishTime: publishTime});
    }

    function setUpdateFee(uint256 fee) external {
        updateFee = fee;
    }

    function getValidTimePeriod() external pure override returns (uint256) {
        return 60;
    }

    function getPriceUnsafe(bytes32 id) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getPriceNoOlderThan(bytes32 id, uint256 age) external view override returns (PythStructs.Price memory price) {
        price = prices[id];
        require(block.timestamp - price.publishTime <= age, "Price too old");
        return price;
    }

    function getEmaPriceUnsafe(bytes32 id) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getEmaPriceNoOlderThan(bytes32 id, uint256 age)
        external
        view
        override
        returns (PythStructs.Price memory price)
    {
        price = prices[id];
        require(block.timestamp - price.publishTime <= age, "Price too old");
        return price;
    }

    function updatePriceFeeds(bytes[] calldata) external payable override {
        require(msg.value >= updateFee, "Insufficient fee");
    }

    function updatePriceFeedsIfNecessary(bytes[] calldata, bytes32[] calldata, uint64[] calldata)
        external
        payable
        override
    {
        require(msg.value >= updateFee, "Insufficient fee");
    }

    function getUpdateFee(bytes[] calldata updateData) external view override returns (uint256 feeAmount) {
        return updateFee * updateData.length;
    }

    function parsePriceFeedUpdates(
        bytes[] calldata,
        bytes32[] calldata,
        uint64,
        uint64
    ) external payable override returns (PythStructs.PriceFeed[] memory) {
        revert("Not implemented");
    }
}
