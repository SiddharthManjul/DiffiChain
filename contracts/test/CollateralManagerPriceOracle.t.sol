// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollateralManager} from "../src/core/CollateralManager.sol";
import {PriceOracle} from "../src/core/PriceOracle.sol";
import {MockPyth} from "./mocks/MockPyth.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract CollateralManagerPriceOracleTest is Test {
    CollateralManager public collateralManager;
    PriceOracle public priceOracle;
    MockPyth public mockPyth;
    MockERC20 public underlyingToken;
    MockERC20 public zkToken;

    address public owner = address(this);
    address public user = address(0x1);

    bytes32 public constant ETH_USD_PRICE_FEED_ID =
        0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    function setUp() public {
        // Deploy mock contracts
        mockPyth = new MockPyth();
        underlyingToken = new MockERC20("Wrapped Ether", "WETH", 18);
        zkToken = new MockERC20("zkETH", "zETH", 18);

        // Deploy PriceOracle
        priceOracle = new PriceOracle(address(mockPyth));

        // Deploy CollateralManager with PriceOracle
        collateralManager = new CollateralManager(address(priceOracle));

        // Set ETH/USD price to $2000
        mockPyth.setPrice(
            ETH_USD_PRICE_FEED_ID,
            2000_00000000, // $2000 with 8 decimals
            1_00000000,
            -8,
            block.timestamp
        );

        // Register price feed
        priceOracle.registerPriceFeed(address(underlyingToken), ETH_USD_PRICE_FEED_ID);

        // Register zkToken with CollateralManager
        collateralManager.registerZkToken(address(zkToken), address(underlyingToken));

        // Mint tokens to zkToken contract for testing
        underlyingToken.mint(address(zkToken), 100 ether);
    }

    // ============ Deployment Tests ============

    function testCollateralManagerDeployedWithPriceOracle() public view {
        assertEq(collateralManager.getPriceOracle(), address(priceOracle));
    }

    function testCollateralManagerCanBeDeployedWithoutPriceOracle() public {
        CollateralManager newManager = new CollateralManager(address(0));
        assertEq(newManager.getPriceOracle(), address(0));
    }

    // ============ Price Oracle Update Tests ============

    function testSetPriceOracle() public {
        PriceOracle newOracle = new PriceOracle(address(mockPyth));

        collateralManager.setPriceOracle(address(newOracle));

        assertEq(collateralManager.getPriceOracle(), address(newOracle));
    }

    function testSetPriceOracleEmitsEvent() public {
        PriceOracle newOracle = new PriceOracle(address(mockPyth));

        vm.expectEmit(true, true, false, true);
        emit CollateralManager.PriceOracleUpdated(address(priceOracle), address(newOracle));

        collateralManager.setPriceOracle(address(newOracle));
    }

    function testOnlyOwnerCanSetPriceOracle() public {
        PriceOracle newOracle = new PriceOracle(address(mockPyth));

        vm.prank(user);
        vm.expectRevert();
        collateralManager.setPriceOracle(address(newOracle));
    }

    // ============ Price Query Tests ============

    function testGetUnderlyingTokenPrice() public view {
        uint256 price = collateralManager.getUnderlyingTokenPrice(address(zkToken), 18);

        // Expected: $2000 with 18 decimals
        assertEq(price, 2000 * 10 ** 18);
    }

    function testGetUnderlyingTokenPriceWithDifferentDecimals() public view {
        uint256 price = collateralManager.getUnderlyingTokenPrice(address(zkToken), 6);

        // Expected: $2000 with 6 decimals
        assertEq(price, 2000 * 10 ** 6);
    }

    function testGetUnderlyingTokenPriceUnregisteredZkToken() public {
        address unregisteredToken = address(0x999);

        vm.expectRevert(CollateralManager.ZkTokenNotRegistered.selector);
        collateralManager.getUnderlyingTokenPrice(unregisteredToken, 18);
    }

    function testGetUnderlyingTokenPriceWithoutOracle() public {
        CollateralManager managerWithoutOracle = new CollateralManager(address(0));

        vm.expectRevert(CollateralManager.InvalidAddress.selector);
        managerWithoutOracle.getUnderlyingTokenPrice(address(zkToken), 18);
    }

    // ============ Collateral Value Tests ============

    function testGetTotalCollateralValue() public {
        // Lock 10 ETH collateral
        vm.startPrank(address(zkToken));
        underlyingToken.approve(address(collateralManager), 10 ether);
        collateralManager.lockCollateral(address(zkToken), 10 ether, bytes32(uint256(1)));
        vm.stopPrank();

        // Get collateral value with 18 decimals
        uint256 value = collateralManager.getTotalCollateralValue(address(zkToken), 18);

        // Expected: 10 ETH * $2000/ETH = $20,000
        assertEq(value, 20_000 * 10 ** 18);
    }

    function testGetTotalCollateralValueWithDifferentPrice() public {
        // Update ETH price to $3000
        mockPyth.setPrice(ETH_USD_PRICE_FEED_ID, 3000_00000000, 1_00000000, -8, block.timestamp);

        // Lock 5 ETH collateral
        vm.startPrank(address(zkToken));
        underlyingToken.approve(address(collateralManager), 5 ether);
        collateralManager.lockCollateral(address(zkToken), 5 ether, bytes32(uint256(1)));
        vm.stopPrank();

        // Get collateral value
        uint256 value = collateralManager.getTotalCollateralValue(address(zkToken), 18);

        // Expected: 5 ETH * $3000/ETH = $15,000
        assertEq(value, 15_000 * 10 ** 18);
    }

    function testGetTotalCollateralValueZeroCollateral() public view {
        uint256 value = collateralManager.getTotalCollateralValue(address(zkToken), 18);

        assertEq(value, 0);
    }

    function testGetTotalCollateralValueAfterReleasing() public {
        // Lock 20 ETH
        vm.startPrank(address(zkToken));
        underlyingToken.approve(address(collateralManager), 20 ether);
        collateralManager.lockCollateral(address(zkToken), 20 ether, bytes32(uint256(1)));

        // Release 10 ETH
        collateralManager.releaseCollateral(address(zkToken), user, 10 ether, bytes32(uint256(2)));
        vm.stopPrank();

        // Get remaining collateral value
        uint256 value = collateralManager.getTotalCollateralValue(address(zkToken), 18);

        // Expected: 10 ETH * $2000/ETH = $20,000
        assertEq(value, 20_000 * 10 ** 18);
    }

    function testGetTotalCollateralValueUnregisteredToken() public {
        address unregisteredToken = address(0x999);

        vm.expectRevert(CollateralManager.ZkTokenNotRegistered.selector);
        collateralManager.getTotalCollateralValue(unregisteredToken, 18);
    }

    function testGetTotalCollateralValueWithoutOracle() public {
        CollateralManager managerWithoutOracle = new CollateralManager(address(0));
        managerWithoutOracle.registerZkToken(address(zkToken), address(underlyingToken));

        vm.expectRevert(CollateralManager.InvalidAddress.selector);
        managerWithoutOracle.getTotalCollateralValue(address(zkToken), 18);
    }

    // ============ Integration Tests ============

    function testPriceOracleIntegrationFlow() public {
        // 1. Lock collateral at $2000/ETH
        vm.startPrank(address(zkToken));
        underlyingToken.approve(address(collateralManager), 10 ether);
        collateralManager.lockCollateral(address(zkToken), 10 ether, bytes32(uint256(1)));
        vm.stopPrank();

        // Check initial value
        uint256 initialValue = collateralManager.getTotalCollateralValue(address(zkToken), 18);
        assertEq(initialValue, 20_000 * 10 ** 18);

        // 2. Update price to $2500/ETH
        mockPyth.setPrice(ETH_USD_PRICE_FEED_ID, 2500_00000000, 1_00000000, -8, block.timestamp);

        // Check updated value (same collateral, new price)
        uint256 updatedValue = collateralManager.getTotalCollateralValue(address(zkToken), 18);
        assertEq(updatedValue, 25_000 * 10 ** 18);

        // 3. Lock more collateral at new price
        vm.startPrank(address(zkToken));
        underlyingToken.approve(address(collateralManager), 10 ether);
        collateralManager.lockCollateral(address(zkToken), 10 ether, bytes32(uint256(2)));
        vm.stopPrank();

        // Check final value: 20 ETH * $2500 = $50,000
        uint256 finalValue = collateralManager.getTotalCollateralValue(address(zkToken), 18);
        assertEq(finalValue, 50_000 * 10 ** 18);
    }

    function testMultipleTokensWithDifferentPrices() public {
        // Setup second token (e.g., WBTC)
        MockERC20 wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
        MockERC20 zkBtc = new MockERC20("zkBTC", "zBTC", 8);

        bytes32 btcUsdPriceFeedId = bytes32(uint256(999));

        // BTC price = $40,000
        mockPyth.setPrice(btcUsdPriceFeedId, 40000_00000000, 1_00000000, -8, block.timestamp);

        // Register BTC price feed and zkToken
        priceOracle.registerPriceFeed(address(wbtc), btcUsdPriceFeedId);
        collateralManager.registerZkToken(address(zkBtc), address(wbtc));

        // Mint and lock ETH collateral
        underlyingToken.mint(address(zkToken), 10 ether);
        vm.startPrank(address(zkToken));
        underlyingToken.approve(address(collateralManager), 10 ether);
        collateralManager.lockCollateral(address(zkToken), 10 ether, bytes32(uint256(1)));
        vm.stopPrank();

        // Mint and lock BTC collateral (0.5 BTC = 50000000 satoshis)
        wbtc.mint(address(zkBtc), 0.5e8);
        vm.startPrank(address(zkBtc));
        wbtc.approve(address(collateralManager), 0.5e8);
        collateralManager.lockCollateral(address(zkBtc), 0.5e8, bytes32(uint256(2)));
        vm.stopPrank();

        // Check ETH collateral value: 10 ETH * $2000 = $20,000
        uint256 ethValue = collateralManager.getTotalCollateralValue(address(zkToken), 18);
        assertEq(ethValue, 20_000 * 10 ** 18);

        // Check BTC collateral value: 0.5 BTC * $40,000 = $20,000
        // Note: WBTC has 8 decimals, so 0.5 BTC = 50000000 units
        uint256 btcValue = collateralManager.getTotalCollateralValue(address(zkBtc), 18);
        // Expected: (50000000 * 40000 * 10^18) / 10^8 = 20,000 * 10^18
        assertEq(btcValue, 20_000 * 10 ** 18);
    }

    function testPriceUpdateAffectsOnlyReads() public {
        // Lock collateral
        vm.startPrank(address(zkToken));
        underlyingToken.approve(address(collateralManager), 10 ether);
        collateralManager.lockCollateral(address(zkToken), 10 ether, bytes32(uint256(1)));
        vm.stopPrank();

        // Check collateral amount (shouldn't change with price)
        uint256 collateralAmount = collateralManager.getTotalCollateral(address(zkToken));
        assertEq(collateralAmount, 10 ether);

        // Update price
        mockPyth.setPrice(ETH_USD_PRICE_FEED_ID, 5000_00000000, 1_00000000, -8, block.timestamp);

        // Collateral amount should remain the same
        assertEq(collateralManager.getTotalCollateral(address(zkToken)), 10 ether);

        // But value should change
        uint256 value = collateralManager.getTotalCollateralValue(address(zkToken), 18);
        assertEq(value, 50_000 * 10 ** 18);
    }
}
