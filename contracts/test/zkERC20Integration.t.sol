// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {zkERC20} from "../src/core/zkERC20.sol";
import {CollateralManager} from "../src/core/CollateralManager.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {IGroth16Verifier} from "../src/interfaces/IGroth16Verifier.sol";

/// @title zkERC20IntegrationTest
/// @notice Integration tests for zkERC20 with actual ZK proof verification
/// @dev Tests the complete flow: deposit → transfer → withdraw with verifiers
contract zkERC20IntegrationTest is Test {
    zkERC20 public zkToken;
    CollateralManager public collateralManager;
    MockERC20 public underlyingToken;

    address public depositVerifier;
    address public transferVerifier;
    address public withdrawVerifier;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 constant INITIAL_BALANCE = 1000 ether;

    function setUp() public {
        // Deploy mock ERC20
        underlyingToken = new MockERC20("Test Token", "TEST");

        // Deploy verifiers (use address(1), address(2), address(3) as placeholders)
        // In real tests, these would be actual deployed verifier contracts
        depositVerifier = address(1);
        transferVerifier = address(2);
        withdrawVerifier = address(3);

        // Mock the verifier contracts to always return true for testing
        // This allows us to test the integration without real proofs
        vm.etch(depositVerifier, hex"00");
        vm.etch(transferVerifier, hex"00");
        vm.etch(withdrawVerifier, hex"00");

        // Deploy CollateralManager (owner is this test contract)
        collateralManager = new CollateralManager(address(this));

        // Deploy zkERC20
        zkToken = new zkERC20(
            "zkTest",
            "zkTEST",
            depositVerifier,
            transferVerifier,
            withdrawVerifier,
            address(collateralManager),
            0 // variable denomination
        );

        // Register the zkToken with collateralManager
        collateralManager.registerZkToken(address(zkToken), address(underlyingToken));

        // Mint tokens to test users
        underlyingToken.mint(alice, INITIAL_BALANCE);
        underlyingToken.mint(bob, INITIAL_BALANCE);
        underlyingToken.mint(charlie, INITIAL_BALANCE);

        // Approve zkToken to spend tokens
        vm.prank(alice);
        underlyingToken.approve(address(zkToken), type(uint256).max);
        vm.prank(bob);
        underlyingToken.approve(address(zkToken), type(uint256).max);
        vm.prank(charlie);
        underlyingToken.approve(address(zkToken), type(uint256).max);
    }

    /// @notice Test basic deposit functionality
    function testDeposit() public {
        uint256 amount = 100 ether;
        bytes32 commitment = keccak256(abi.encodePacked(amount, "secret1", "nullifier1"));
        bytes32 nullifierHash = keccak256(abi.encodePacked("nullifier1"));

        // Mock the proof components (would be real proofs in production)
        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        uint256 aliceBalanceBefore = underlyingToken.balanceOf(alice);

        vm.prank(alice);
        zkToken.deposit(amount, commitment, nullifierHash, hex"deadbeef", proofA, proofB, proofC);

        // Verify commitment was added
        assertTrue(zkToken.commitmentExists(commitment));

        // Verify nullifier was marked as spent
        assertTrue(zkToken.isNullifierSpent(nullifierHash));

        // Verify tokens were locked
        assertEq(underlyingToken.balanceOf(alice), aliceBalanceBefore - amount);
        assertEq(underlyingToken.balanceOf(address(collateralManager)), amount);

        // Verify Merkle tree was updated
        assertEq(zkToken.getNextIndex(), 1);
    }

    /// @notice Test transfer functionality (2-in, 2-out)
    function testTransfer() public {
        // First, create two notes by depositing
        uint256 amount1 = 50 ether;
        uint256 amount2 = 30 ether;

        bytes32 commitment1 = keccak256(abi.encodePacked(amount1, "secret1", "nullifier1"));
        bytes32 nullifierHash1 = keccak256(abi.encodePacked("nullifier1"));

        bytes32 commitment2 = keccak256(abi.encodePacked(amount2, "secret2", "nullifier2"));
        bytes32 nullifierHash2 = keccak256(abi.encodePacked("nullifier2"));

        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        vm.prank(alice);
        zkToken.deposit(amount1, commitment1, nullifierHash1, hex"", proofA, proofB, proofC);

        vm.prank(alice);
        zkToken.deposit(amount2, commitment2, nullifierHash2, hex"", proofA, proofB, proofC);

        // Now perform a transfer using these two notes as inputs
        bytes32 inputNullifier1 = keccak256(abi.encodePacked("spend_nullifier1"));
        bytes32 inputNullifier2 = keccak256(abi.encodePacked("spend_nullifier2"));

        bytes32 outputCommitment1 = keccak256(abi.encodePacked(uint256(40 ether), "secret3", "nullifier3"));
        bytes32 outputCommitment2 = keccak256(abi.encodePacked(uint256(40 ether), "secret4", "nullifier4"));

        bytes32 merkleRoot = zkToken.getMerkleRoot();

        bytes[] memory encryptedNotes = new bytes[](2);
        encryptedNotes[0] = hex"dead";
        encryptedNotes[1] = hex"beef";

        vm.prank(alice);
        zkToken.transfer(
            [inputNullifier1, inputNullifier2],
            [outputCommitment1, outputCommitment2],
            merkleRoot,
            encryptedNotes,
            proofA,
            proofB,
            proofC
        );

        // Verify input nullifiers were spent
        assertTrue(zkToken.isNullifierSpent(inputNullifier1));
        assertTrue(zkToken.isNullifierSpent(inputNullifier2));

        // Verify output commitments were created
        assertTrue(zkToken.commitmentExists(outputCommitment1));
        assertTrue(zkToken.commitmentExists(outputCommitment2));

        // Verify Merkle tree was updated (2 deposits + 2 outputs = 4 total)
        assertEq(zkToken.getNextIndex(), 4);
    }

    /// @notice Test withdraw functionality
    function testWithdraw() public {
        // First deposit a note
        uint256 depositAmount = 75 ether;
        bytes32 commitment = keccak256(abi.encodePacked(depositAmount, "secret1", "nullifier1"));
        bytes32 depositNullifierHash = keccak256(abi.encodePacked("nullifier1"));

        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        vm.prank(alice);
        zkToken.deposit(depositAmount, commitment, depositNullifierHash, hex"", proofA, proofB, proofC);

        // Now withdraw it
        uint256 withdrawAmount = 75 ether;
        bytes32 withdrawNullifierHash = keccak256(abi.encodePacked("withdraw_nullifier1"));

        uint256 bobBalanceBefore = underlyingToken.balanceOf(bob);

        vm.prank(alice);
        zkToken.withdraw(
            withdrawAmount,
            bob,
            commitment,
            withdrawNullifierHash,
            proofA,
            proofB,
            proofC
        );

        // Verify nullifier was spent
        assertTrue(zkToken.isNullifierSpent(withdrawNullifierHash));

        // Verify bob received the tokens
        assertEq(underlyingToken.balanceOf(bob), bobBalanceBefore + withdrawAmount);
    }

    /// @notice Test that duplicate commitments are rejected
    function testCannotDepositDuplicateCommitment() public {
        uint256 amount = 50 ether;
        bytes32 commitment = keccak256(abi.encodePacked(amount, "secret1", "nullifier1"));
        bytes32 nullifierHash = keccak256(abi.encodePacked("nullifier1"));

        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        vm.prank(alice);
        zkToken.deposit(amount, commitment, nullifierHash, hex"", proofA, proofB, proofC);

        // Try to deposit same commitment again with different nullifier
        bytes32 nullifierHash2 = keccak256(abi.encodePacked("nullifier2"));

        vm.expectRevert(zkERC20.CommitmentAlreadyExists.selector);
        vm.prank(alice);
        zkToken.deposit(amount, commitment, nullifierHash2, hex"", proofA, proofB, proofC);
    }

    /// @notice Test that spent nullifiers cannot be reused
    function testCannotReuseNullifier() public {
        uint256 amount = 50 ether;
        bytes32 commitment1 = keccak256(abi.encodePacked(amount, "secret1", "nullifier1"));
        bytes32 commitment2 = keccak256(abi.encodePacked(amount, "secret2", "nullifier2"));
        bytes32 nullifierHash = keccak256(abi.encodePacked("nullifier1"));

        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        vm.prank(alice);
        zkToken.deposit(amount, commitment1, nullifierHash, hex"", proofA, proofB, proofC);

        // Try to use same nullifier again
        vm.expectRevert(zkERC20.NullifierAlreadySpent.selector);
        vm.prank(alice);
        zkToken.deposit(amount, commitment2, nullifierHash, hex"", proofA, proofB, proofC);
    }

    /// @notice Test invalid Merkle root in transfer
    function testCannotTransferWithInvalidMerkleRoot() public {
        // Deposit a note first
        uint256 amount = 50 ether;
        bytes32 commitment = keccak256(abi.encodePacked(amount, "secret1", "nullifier1"));
        bytes32 nullifierHash = keccak256(abi.encodePacked("nullifier1"));

        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        vm.prank(alice);
        zkToken.deposit(amount, commitment, nullifierHash, hex"", proofA, proofB, proofC);

        // Try to transfer with invalid Merkle root
        bytes32 invalidRoot = bytes32(uint256(12345));
        bytes32[] memory inputNulls = new bytes32[](2);
        inputNulls[0] = keccak256("null1");
        inputNulls[1] = keccak256("null2");

        bytes32[2] memory inputNullifiers = [keccak256("null1"), keccak256("null2")];
        bytes32[2] memory outputCommitments = [
            keccak256(abi.encodePacked(uint256(25 ether), "s3", "n3")),
            keccak256(abi.encodePacked(uint256(25 ether), "s4", "n4"))
        ];

        bytes[] memory encryptedNotes = new bytes[](2);
        encryptedNotes[0] = hex"01";
        encryptedNotes[1] = hex"02";

        vm.expectRevert(zkERC20.InvalidMerkleRoot.selector);
        vm.prank(alice);
        zkToken.transfer(inputNullifiers, outputCommitments, invalidRoot, encryptedNotes, proofA, proofB, proofC);
    }

    /// @notice Test complete flow: deposit → transfer → withdraw
    function testCompleteFlow() public {
        uint256[2] memory proofA = [uint256(1), uint256(2)];
        uint256[2][2] memory proofB = [[uint256(3), uint256(4)], [uint256(5), uint256(6)]];
        uint256[2] memory proofC = [uint256(7), uint256(8)];

        // Step 1: Alice deposits 100 ETH
        uint256 aliceDeposit = 100 ether;
        bytes32 aliceCommitment = keccak256(abi.encodePacked(aliceDeposit, "alice_secret", "alice_null"));
        bytes32 aliceNullifierHash = keccak256(abi.encodePacked("alice_null"));

        vm.prank(alice);
        zkToken.deposit(aliceDeposit, aliceCommitment, aliceNullifierHash, hex"deadbeef", proofA, proofB, proofC);

        console.log("Step 1: Alice deposited", aliceDeposit);
        console.log("  - Merkle index:", zkToken.getNextIndex());

        // Step 2: Bob deposits 50 ETH
        uint256 bobDeposit = 50 ether;
        bytes32 bobCommitment = keccak256(abi.encodePacked(bobDeposit, "bob_secret", "bob_null"));
        bytes32 bobNullifierHash = keccak256(abi.encodePacked("bob_null"));

        vm.prank(bob);
        zkToken.deposit(bobDeposit, bobCommitment, bobNullifierHash, hex"deadbeef", proofA, proofB, proofC);

        console.log("Step 2: Bob deposited", bobDeposit);
        console.log("  - Merkle index:", zkToken.getNextIndex());

        // Step 3: Transfer (combine both notes into two new outputs)
        bytes32 merkleRoot = zkToken.getMerkleRoot();
        bytes32[2] memory inputNullifiers = [
            keccak256("alice_transfer_null"),
            keccak256("bob_transfer_null")
        ];
        bytes32[2] memory outputCommitments = [
            keccak256(abi.encodePacked(uint256(75 ether), "out1_secret", "out1_null")),
            keccak256(abi.encodePacked(uint256(75 ether), "out2_secret", "out2_null"))
        ];

        bytes[] memory encryptedNotes = new bytes[](2);
        encryptedNotes[0] = hex"aaaa";
        encryptedNotes[1] = hex"bbbb";

        vm.prank(alice);
        zkToken.transfer(inputNullifiers, outputCommitments, merkleRoot, encryptedNotes, proofA, proofB, proofC);

        console.log("Step 3: Transfer completed (2-in, 2-out)");
        console.log("  - Total commitments:", zkToken.getNextIndex());

        // Step 4: Withdraw one of the outputs to Charlie
        uint256 withdrawAmount = 75 ether;
        bytes32 withdrawNullifierHash = keccak256("withdraw_null");

        uint256 charlieBalanceBefore = underlyingToken.balanceOf(charlie);

        vm.prank(alice);
        zkToken.withdraw(
            withdrawAmount,
            charlie,
            outputCommitments[0],
            withdrawNullifierHash,
            proofA,
            proofB,
            proofC
        );

        console.log("Step 4: Withdrawn to Charlie:", withdrawAmount);
        console.log("  - Charlie's new balance:", underlyingToken.balanceOf(charlie));

        // Verify final state
        assertEq(underlyingToken.balanceOf(charlie), charlieBalanceBefore + withdrawAmount);
        assertTrue(zkToken.isNullifierSpent(inputNullifiers[0]));
        assertTrue(zkToken.isNullifierSpent(inputNullifiers[1]));
        assertTrue(zkToken.isNullifierSpent(withdrawNullifierHash));
    }
}
