// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {zkERC20} from "../src/core/zkERC20.sol";
import {CollateralManager} from "../src/core/CollateralManager.sol";
import {StealthAddressRegistry} from "../src/core/StealthAddressRegistry.sol";
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

        // 2. Deploy CollateralManager
        console.log("\nDeploying CollateralManager...");
        CollateralManager collateralManager = new CollateralManager();
        console.log("CollateralManager:", address(collateralManager));

        // 3. Deploy StealthAddressRegistry
        console.log("\nDeploying StealthAddressRegistry...");
        StealthAddressRegistry stealthRegistry = new StealthAddressRegistry();
        console.log("StealthAddressRegistry:", address(stealthRegistry));

        // 4. Deploy zkERC20 (example: zkETH with 1 ETH denomination)
        console.log("\nDeploying zkERC20 (zkETH)...");
        zkERC20 zkETH = new zkERC20(
            "zkEther",
            "zETH",
            address(depositVerifier),
            address(transferVerifier),
            address(withdrawVerifier),
            address(collateralManager),
            1 ether // Fixed denomination: 1 ETH
        );
        console.log("zkETH:", address(zkETH));

        // 5. Register zkETH with CollateralManager
        // Note: For testnet, you'd specify the actual ERC20 token address (e.g., WETH)
        // For this example, we'll use address(0) as placeholder - update with actual token
        address underlyingETH = vm.envOr("UNDERLYING_ETH_ADDRESS", address(0));

        if (underlyingETH != address(0)) {
            console.log("\nRegistering zkETH with CollateralManager...");
            collateralManager.registerZkToken(address(zkETH), underlyingETH);
            console.log("zkETH registered with underlying token:", underlyingETH);
        } else {
            console.log("\nWARNING: No underlying ETH token specified. Set UNDERLYING_ETH_ADDRESS in .env");
            console.log("Skipping zkToken registration...");
        }

        vm.stopBroadcast();

        // Print summary
        console.log("\n========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("Deposit Verifier:      ", address(depositVerifier));
        console.log("Transfer Verifier:     ", address(transferVerifier));
        console.log("Withdraw Verifier:     ", address(withdrawVerifier));
        console.log("CollateralManager:     ", address(collateralManager));
        console.log("StealthAddressRegistry:", address(stealthRegistry));
        console.log("zkETH:                 ", address(zkETH));
        console.log("========================================");
        console.log("\nNext steps:");
        console.log("1. Replace mock verifiers with actual snarkjs-generated verifiers");
        console.log("2. Update .env with deployed contract addresses");
        console.log("3. Update indexer config.yaml with contract addresses");
        console.log("4. Register additional zkERC20 tokens if needed");
    }
}
