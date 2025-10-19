// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

/// @title PythStructs
/// @notice Structs used by Pyth Network
library PythStructs {
    struct Price {
        int64 price;
        uint64 conf;
        int32 expo;
        uint256 publishTime;
    }

    struct PriceFeed {
        bytes32 id;
        Price price;
        Price emaPrice;
    }
}
