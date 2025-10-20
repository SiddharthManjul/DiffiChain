// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IzkERC20} from "../interfaces/IzkERC20.sol";
import {IGroth16Verifier} from "../interfaces/IGroth16Verifier.sol";
import {ICollateralManager} from "../interfaces/ICollateralManager.sol";
import {MerkleTree} from "../libraries/MerkleTree.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title zkERC20
/// @notice Confidential ERC20 token using zero-knowledge proofs and note-based UTXO model
/// @dev All balances and transfers are private - only commitments and nullifiers are public
contract zkERC20 is IzkERC20, Ownable, ReentrancyGuard {
    using MerkleTree for MerkleTree.Tree;

    // ============ State Variables ============

    /// @notice Verifier for deposit proofs
    IGroth16Verifier public immutable DEPOSIT_VERIFIER;

    /// @notice Verifier for transfer proofs
    IGroth16Verifier public immutable TRANSFER_VERIFIER;

    /// @notice Verifier for withdrawal proofs
    IGroth16Verifier public immutable WITHDRAW_VERIFIER;

    /// @notice Collateral manager for ERC20 backing
    ICollateralManager public immutable COLLATERAL_MANAGER;

    /// @notice Merkle tree storing note commitments
    MerkleTree.Tree private commitmentTree;

    /// @notice Mapping of spent nullifiers (prevents double-spending)
    mapping(bytes32 => bool) public nullifiers;

    /// @notice Mapping of commitments to their index
    mapping(bytes32 => uint256) public commitmentIndex;

    /// @notice Token name
    string public name;

    /// @notice Token symbol
    string public symbol;

    /// @notice Denomination (optional - for fixed-denomination privacy)
    uint256 public immutable DENOMINATION;

    // ============ Errors ============

    error InvalidProof();
    error NullifierAlreadySpent();
    error InvalidMerkleRoot();
    error CommitmentAlreadyExists();
    error InvalidCommitment();
    error InvalidArrayLength();
    error TransferFailed();

    // ============ Constructor ============

    /// @notice Initialize the zkERC20 token
    /// @param _name Token name
    /// @param _symbol Token symbol
    /// @param _depositVerifier Address of deposit proof verifier
    /// @param _transferVerifier Address of transfer proof verifier
    /// @param _withdrawVerifier Address of withdrawal proof verifier
    /// @param _collateralManager Address of collateral manager
    /// @param _denomination Fixed denomination (0 for variable amounts)
    constructor(
        string memory _name,
        string memory _symbol,
        address _depositVerifier,
        address _transferVerifier,
        address _withdrawVerifier,
        address _collateralManager,
        uint256 _denomination
    ) Ownable(msg.sender) {
        name = _name;
        symbol = _symbol;
        DEPOSIT_VERIFIER = IGroth16Verifier(_depositVerifier);
        TRANSFER_VERIFIER = IGroth16Verifier(_transferVerifier);
        WITHDRAW_VERIFIER = IGroth16Verifier(_withdrawVerifier);
        COLLATERAL_MANAGER = ICollateralManager(_collateralManager);
        DENOMINATION = _denomination;

        // Initialize Merkle tree
        commitmentTree.initialize();
    }

    // ============ Deposit (Mint) ============

    /// @notice Deposit ERC20 tokens and mint a confidential note
    /// @param amount Amount to deposit (revealed for collateral locking)
    /// @param commitment The commitment of the new note
    /// @param nullifierHash Hash of the nullifier
    /// @param encryptedNote Encrypted note data for the recipient
    /// @param proofA Groth16 proof component A
    /// @param proofB Groth16 proof component B
    /// @param proofC Groth16 proof component C
    function deposit(
        uint256 amount,
        bytes32 commitment,
        bytes32 nullifierHash,
        bytes calldata encryptedNote,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external nonReentrant {
        // Check commitment doesn't already exist
        if (_commitmentExists(commitment)) {
            revert CommitmentAlreadyExists();
        }

        // Check nullifier hasn't been used
        if (nullifiers[nullifierHash]) {
            revert NullifierAlreadySpent();
        }

        // Verify ZK proof
        // Circuit public outputs: [commitment, nullifierHash]
        uint256[] memory publicInputs = new uint256[](2);
        publicInputs[0] = uint256(commitment);
        publicInputs[1] = uint256(nullifierHash);

        bool proofValid = DEPOSIT_VERIFIER.verifyProof(proofA, proofB, proofC, publicInputs);
        if (!proofValid) {
            revert InvalidProof();
        }

        // Transfer from user to this contract first, then to CollateralManager
        address underlyingToken = COLLATERAL_MANAGER.getUnderlyingToken(address(this));
        require(IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        IERC20(underlyingToken).approve(address(COLLATERAL_MANAGER), amount);

        bool locked = COLLATERAL_MANAGER.lockCollateral(address(this), amount, commitment);
        if (!locked) {
            revert TransferFailed();
        }

        // Mark nullifier as used (prevents reusing same note for multiple deposits)
        nullifiers[nullifierHash] = true;

        // Insert commitment into Merkle tree
        uint256 index = commitmentTree.insert(commitment);
        commitmentIndex[commitment] = index;

        // Emit events (no amounts or addresses)
        emit NoteCommitted(commitment, index, encryptedNote);
        emit Deposit(commitment);
    }

    // ============ Transfer ============

    /// @notice Transfer confidential tokens (2-in, 2-out)
    /// @param inputNullifiers Nullifiers of 2 input notes being spent
    /// @param outputCommitments Commitments of 2 new output notes
    /// @param merkleRoot Merkle root proving input notes exist
    /// @param encryptedNotes Encrypted note data for recipients (2 notes)
    /// @param proofA Groth16 proof component A
    /// @param proofB Groth16 proof component B
    /// @param proofC Groth16 proof component C
    function transfer(
        bytes32[2] calldata inputNullifiers,
        bytes32[2] calldata outputCommitments,
        bytes32 merkleRoot,
        bytes[] calldata encryptedNotes,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external nonReentrant {
        _validateTransferInputs(inputNullifiers, outputCommitments, encryptedNotes, merkleRoot);

        _verifyTransferProof(inputNullifiers, outputCommitments, merkleRoot, proofA, proofB, proofC);

        _processTransfer(inputNullifiers, outputCommitments, encryptedNotes);
    }

    /// @dev Validate transfer inputs
    function _validateTransferInputs(
        bytes32[2] calldata inputNullifiers,
        bytes32[2] calldata outputCommitments,
        bytes[] calldata encryptedNotes,
        bytes32 merkleRoot
    ) private view {
        if (encryptedNotes.length != 2) {
            revert InvalidArrayLength();
        }

        // Check nullifiers haven't been spent
        if (nullifiers[inputNullifiers[0]] || nullifiers[inputNullifiers[1]]) {
            revert NullifierAlreadySpent();
        }

        // Check commitments don't exist
        if (_commitmentExists(outputCommitments[0]) || _commitmentExists(outputCommitments[1])) {
            revert CommitmentAlreadyExists();
        }

        // Verify Merkle root is valid
        if (merkleRoot != commitmentTree.root) {
            revert InvalidMerkleRoot();
        }
    }

    /// @dev Verify transfer ZK proof
    function _verifyTransferProof(
        bytes32[2] calldata inputNullifiers,
        bytes32[2] calldata outputCommitments,
        bytes32 merkleRoot,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) private view {
        // Circuit public signals: [merkleRoot, inputNullifiers[0], inputNullifiers[1],
        //                          outputCommitments[0], outputCommitments[1]]
        uint256[] memory publicInputs = new uint256[](5);
        publicInputs[0] = uint256(merkleRoot);
        publicInputs[1] = uint256(inputNullifiers[0]);
        publicInputs[2] = uint256(inputNullifiers[1]);
        publicInputs[3] = uint256(outputCommitments[0]);
        publicInputs[4] = uint256(outputCommitments[1]);

        if (!TRANSFER_VERIFIER.verifyProof(proofA, proofB, proofC, publicInputs)) {
            revert InvalidProof();
        }
    }

    /// @dev Process transfer (mark nullifiers spent, insert commitments)
    function _processTransfer(
        bytes32[2] calldata inputNullifiers,
        bytes32[2] calldata outputCommitments,
        bytes[] calldata encryptedNotes
    ) private {
        // Mark nullifiers as spent
        nullifiers[inputNullifiers[0]] = true;
        nullifiers[inputNullifiers[1]] = true;
        emit NullifierSpent(inputNullifiers[0]);
        emit NullifierSpent(inputNullifiers[1]);

        // Insert new commitments
        uint256 index0 = commitmentTree.insert(outputCommitments[0]);
        commitmentIndex[outputCommitments[0]] = index0;
        emit NoteCommitted(outputCommitments[0], index0, encryptedNotes[0]);

        uint256 index1 = commitmentTree.insert(outputCommitments[1]);
        commitmentIndex[outputCommitments[1]] = index1;
        emit NoteCommitted(outputCommitments[1], index1, encryptedNotes[1]);
    }

    // ============ Withdraw (Burn) ============

    /// @notice Withdraw ERC20 tokens by burning a confidential note
    /// @param amount Amount to withdraw (revealed for collateral release)
    /// @param recipient Address to receive the ERC20 tokens
    /// @param commitment Commitment of the note being spent
    /// @param nullifierHash Hash of the nullifier
    /// @param proofA Groth16 proof component A
    /// @param proofB Groth16 proof component B
    /// @param proofC Groth16 proof component C
    function withdraw(
        uint256 amount,
        address recipient,
        bytes32 commitment,
        bytes32 nullifierHash,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external nonReentrant {
        // Check nullifier hasn't been spent
        if (nullifiers[nullifierHash]) {
            revert NullifierAlreadySpent();
        }

        // Verify ZK proof
        // Circuit public signals: [merkleRoot, amount, recipient, commitment, nullifierHash]
        uint256[] memory publicInputs = new uint256[](5);
        publicInputs[0] = uint256(commitmentTree.root);
        publicInputs[1] = amount;
        publicInputs[2] = uint256(uint160(recipient));
        publicInputs[3] = uint256(commitment);
        publicInputs[4] = uint256(nullifierHash);

        bool proofValid = WITHDRAW_VERIFIER.verifyProof(proofA, proofB, proofC, publicInputs);
        if (!proofValid) {
            revert InvalidProof();
        }

        // Mark nullifier as spent
        nullifiers[nullifierHash] = true;
        emit NullifierSpent(nullifierHash);
        emit Withdrawal(nullifierHash);

        // Release collateral
        bool released = COLLATERAL_MANAGER.releaseCollateral(
            address(this),
            recipient,
            amount,
            nullifierHash
        );
        if (!released) {
            revert TransferFailed();
        }
    }

    // ============ View Functions ============

    /// @notice Check if a commitment exists
    function commitmentExists(bytes32 commitment) external view override returns (bool) {
        return _commitmentExists(commitment);
    }

    /// @dev Internal helper to check commitment existence
    function _commitmentExists(bytes32 commitment) private view returns (bool) {
        uint256 index = commitmentIndex[commitment];
        return index > 0 || (commitment == commitmentTree.leaves[0] && commitmentTree.nextIndex > 0);
    }

    /// @notice Check if a nullifier has been spent
    function isNullifierSpent(bytes32 nullifier) external view override returns (bool) {
        return nullifiers[nullifier];
    }

    /// @notice Get current Merkle root
    function getMerkleRoot() external view override returns (bytes32) {
        return commitmentTree.getRoot();
    }

    /// @notice Get next available index
    function getNextIndex() external view override returns (uint256) {
        return commitmentTree.getNextIndex();
    }

}
