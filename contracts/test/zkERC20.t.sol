// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {zkERC20} from "../src/core/zkERC20.sol";
import {CollateralManager} from "../src/core/CollateralManager.sol";
import {StealthAddressRegistry} from "../src/core/StealthAddressRegistry.sol";
import {MockGroth16Verifier, MockFailingVerifier} from "./mocks/MockGroth16Verifier.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract zkERC20Test is Test {
    zkERC20 public zkToken;
    CollateralManager public collateralManager;
    StealthAddressRegistry public stealthRegistry;
    MockGroth16Verifier public depositVerifier;
    MockGroth16Verifier public transferVerifier;
    MockGroth16Verifier public withdrawVerifier;
    MockERC20 public underlyingToken;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    uint256 public constant DENOMINATION = 1 ether;

    function setUp() public {
        // Deploy mock verifiers
        depositVerifier = new MockGroth16Verifier();
        transferVerifier = new MockGroth16Verifier();
        withdrawVerifier = new MockGroth16Verifier();

        // Deploy collateral manager
        collateralManager = new CollateralManager();

        // Deploy underlying ERC20
        underlyingToken = new MockERC20("Ether", "ETH", 18);

        // Deploy zkERC20
        zkToken = new zkERC20(
            "zkEther",
            "zETH",
            address(depositVerifier),
            address(transferVerifier),
            address(withdrawVerifier),
            address(collateralManager),
            DENOMINATION
        );

        // Register zkToken in collateral manager
        collateralManager.registerZkToken(address(zkToken), address(underlyingToken));

        // Deploy stealth address registry
        stealthRegistry = new StealthAddressRegistry();

        // Setup test accounts with tokens
        underlyingToken.mint(alice, 100 ether);
        underlyingToken.mint(bob, 100 ether);
        underlyingToken.mint(charlie, 100 ether);

        // Approve zkToken contract (users approve zkToken, which then approves CollateralManager)
        vm.prank(alice);
        underlyingToken.approve(address(zkToken), type(uint256).max);

        vm.prank(bob);
        underlyingToken.approve(address(zkToken), type(uint256).max);

        vm.prank(charlie);
        underlyingToken.approve(address(zkToken), type(uint256).max);
    }

    function testDeposit() public {
        bytes32 commitment = keccak256(abi.encodePacked("commitment1"));
        bytes memory encryptedNote = hex"deadbeef";

        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        vm.prank(alice);
        zkToken.deposit(commitment, encryptedNote, proofA, proofB, proofC);

        assertTrue(zkToken.commitmentExists(commitment));
        assertEq(zkToken.getNextIndex(), 1);
        assertEq(collateralManager.getTotalCollateral(address(zkToken)), DENOMINATION);
    }

    function testTransfer() public {
        // First, deposit two notes
        bytes32 commitment1 = keccak256(abi.encodePacked("commitment1"));
        bytes32 commitment2 = keccak256(abi.encodePacked("commitment2"));

        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        vm.prank(alice);
        zkToken.deposit(commitment1, hex"", proofA, proofB, proofC);

        vm.prank(bob);
        zkToken.deposit(commitment2, hex"", proofA, proofB, proofC);

        // Now transfer
        bytes32[] memory inputNullifiers = new bytes32[](1);
        inputNullifiers[0] = keccak256(abi.encodePacked("nullifier1"));

        bytes32[] memory outputCommitments = new bytes32[](1);
        outputCommitments[0] = keccak256(abi.encodePacked("commitment3"));

        bytes[] memory encryptedNotes = new bytes[](1);
        encryptedNotes[0] = hex"cafebabe";

        bytes32 merkleRoot = zkToken.getMerkleRoot();

        vm.prank(alice);
        zkToken.transfer(
            inputNullifiers,
            outputCommitments,
            merkleRoot,
            encryptedNotes,
            proofA,
            proofB,
            proofC
        );

        assertTrue(zkToken.isNullifierSpent(inputNullifiers[0]));
        assertTrue(zkToken.commitmentExists(outputCommitments[0]));
    }

    function testWithdraw() public {
        // First deposit
        bytes32 commitment = keccak256(abi.encodePacked("commitment1"));

        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        vm.prank(alice);
        zkToken.deposit(commitment, hex"", proofA, proofB, proofC);

        // Now withdraw
        bytes32 nullifier = keccak256(abi.encodePacked("nullifier1"));

        uint256 balanceBefore = underlyingToken.balanceOf(bob);

        vm.prank(alice);
        zkToken.withdraw(nullifier, bob, proofA, proofB, proofC);

        assertTrue(zkToken.isNullifierSpent(nullifier));
        assertEq(underlyingToken.balanceOf(bob), balanceBefore + DENOMINATION);
    }

    function testCannotDoubleSpend() public {
        // Deposit
        bytes32 commitment = keccak256(abi.encodePacked("commitment1"));

        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        vm.prank(alice);
        zkToken.deposit(commitment, hex"", proofA, proofB, proofC);

        // Transfer once
        bytes32[] memory inputNullifiers = new bytes32[](1);
        inputNullifiers[0] = keccak256(abi.encodePacked("nullifier1"));

        bytes32[] memory outputCommitments = new bytes32[](1);
        outputCommitments[0] = keccak256(abi.encodePacked("commitment2"));

        bytes[] memory encryptedNotes = new bytes[](1);
        encryptedNotes[0] = hex"";

        bytes32 merkleRoot = zkToken.getMerkleRoot();

        vm.prank(alice);
        zkToken.transfer(
            inputNullifiers,
            outputCommitments,
            merkleRoot,
            encryptedNotes,
            proofA,
            proofB,
            proofC
        );

        // Try to transfer again with same nullifier
        outputCommitments[0] = keccak256(abi.encodePacked("commitment3"));

        vm.prank(alice);
        vm.expectRevert(zkERC20.NullifierAlreadySpent.selector);
        zkToken.transfer(
            inputNullifiers,
            outputCommitments,
            merkleRoot,
            encryptedNotes,
            proofA,
            proofB,
            proofC
        );
    }

    function testStealthAddressRegistry() public {
        bytes memory spendingPubKey = hex"02deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef";
        bytes memory viewingPubKey = hex"03cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe";

        vm.prank(alice);
        stealthRegistry.registerStealthMetaAddress(spendingPubKey, viewingPubKey);

        assertTrue(stealthRegistry.isRegistered(alice));

        (bytes memory storedSpending, bytes memory storedViewing) =
            stealthRegistry.getStealthMetaAddress(alice);

        assertEq(storedSpending, spendingPubKey);
        assertEq(storedViewing, viewingPubKey);
    }

    function testStealthAnnouncement() public {
        bytes memory ephemeralPubKey = hex"02deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef";
        address stealthAddress = address(0x999);
        bytes memory metadata = hex"cafebabe";

        vm.prank(alice);
        stealthRegistry.announce(ephemeralPubKey, stealthAddress, metadata);

        assertEq(stealthRegistry.totalAnnouncements(), 1);
    }
}
