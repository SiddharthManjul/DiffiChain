// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {zkERC20} from "../src/core/zkERC20.sol";
import {CollateralManager} from "../src/core/CollateralManager.sol";
import {StealthAddressRegistry} from "../src/core/StealthAddressRegistry.sol";
import {PriceOracle} from "../src/core/PriceOracle.sol";
import {MockGroth16Verifier} from "../test/mocks/MockGroth16Verifier.sol";

/// @title Deploy
/// @notice Deployment script for DiffiChain contracts
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Verifiers (using mocks for now - replace with actual snarkjs-generated verifiers)
        console.log("Deploying verifiers...");
        MockGroth16Verifier depositVerifier = new MockGroth16Verifier();
        MockGroth16Verifier transferVerifier = new MockGroth16Verifier();
        MockGroth16Verifier withdrawVerifier = new MockGroth16Verifier();

        console.log("Deposit Verifier:", address(depositVerifier));
        console.log("Transfer Verifier:", address(transferVerifier));
        console.log("Withdraw Verifier:", address(withdrawVerifier));

        // 2. Deploy PriceOracle
        console.log("\nDeploying PriceOracle...");
        // Pyth contract address for Monad Testnet: 0x2880aB155794e7179c9eE2e38200202908C17B43
        address pythContract = vm.envOr("PYTH_CONTRACT_ADDRESS", address(0x2880aB155794e7179c9eE2e38200202908C17B43));
        PriceOracle priceOracle = new PriceOracle(pythContract);
        console.log("PriceOracle:", address(priceOracle));
        console.log("Pyth Contract:", pythContract);

        // 3. Deploy CollateralManager with PriceOracle
        console.log("\nDeploying CollateralManager...");
        CollateralManager collateralManager = new CollateralManager(address(priceOracle));
        console.log("CollateralManager:", address(collateralManager));

        // 4. Deploy StealthAddressRegistry
        console.log("\nDeploying StealthAddressRegistry...");
        StealthAddressRegistry stealthRegistry = new StealthAddressRegistry();
        console.log("StealthAddressRegistry:", address(stealthRegistry));

        // 5. Deploy zkERC20 (example: zkETH with 1 ETH denomination)
        console.log("\nDeploying zkERC20 (zkETH)...");
        zkERC20 zkEth = new zkERC20(
            "zkEther",
            "zETH",
            address(depositVerifier),
            address(transferVerifier),
            address(withdrawVerifier),
            address(collateralManager),
            1 ether // Fixed denomination: 1 ETH
        );
        console.log("zkETH:", address(zkEth));

        // 6. Register zkETH with CollateralManager
        // Note: For testnet, you'd specify the actual ERC20 token address (e.g., WETH)
        // For this example, we'll use address(0) as placeholder - update with actual token
        address underlyingEth = vm.envOr("UNDERLYING_ETH_ADDRESS", address(0));

        if (underlyingEth != address(0)) {
            console.log("\nRegistering zkETH with CollateralManager...");
            collateralManager.registerZkToken(address(zkEth), underlyingEth);
            console.log("zkETH registered with underlying token:", underlyingEth);
        } else {
            console.log("\nWARNING: No underlying ETH token specified. Set UNDERLYING_ETH_ADDRESS in .env");
            console.log("Skipping zkToken registration...");
        }

        // 7. Register price feed for underlying token
        // ETH/USD price feed ID on Pyth Network
        bytes32 ethUsdPriceFeedId = vm.envOr(
            "ETH_USD_PRICE_FEED_ID",
            bytes32(0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace)
        );

        if (underlyingEth != address(0) && ethUsdPriceFeedId != bytes32(0)) {
            console.log("\nRegistering ETH/USD price feed...");
            priceOracle.registerPriceFeed(underlyingEth, ethUsdPriceFeedId);
            console.log("ETH/USD price feed registered");
            console.log("Price Feed ID:", vm.toString(ethUsdPriceFeedId));
        }

        vm.stopBroadcast();

        // Print summary
        console.log("\n========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("Deposit Verifier:      ", address(depositVerifier));
        console.log("Transfer Verifier:     ", address(transferVerifier));
        console.log("Withdraw Verifier:     ", address(withdrawVerifier));
        console.log("PriceOracle:           ", address(priceOracle));
        console.log("Pyth Contract:         ", pythContract);
        console.log("CollateralManager:     ", address(collateralManager));
        console.log("StealthAddressRegistry:", address(stealthRegistry));
        console.log("zkETH:                 ", address(zkEth));
        console.log("========================================");
        console.log("\nNext steps:");
        console.log("1. Replace mock verifiers with actual snarkjs-generated verifiers");
        console.log("2. Update .env with deployed contract addresses");
        console.log("3. Update indexer config.yaml with contract addresses");
        console.log("4. Register additional zkERC20 tokens if needed");
        console.log("5. Update price feeds regularly via PriceOracle.updatePriceFeeds()");
        console.log("6. Register additional token price feeds as needed");
    }
}
