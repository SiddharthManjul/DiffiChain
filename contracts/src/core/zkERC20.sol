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
    /// @param commitment The commitment of the new note
    /// @param encryptedNote Encrypted note data for the recipient
    /// @param proofA Groth16 proof component A
    /// @param proofB Groth16 proof component B
    /// @param proofC Groth16 proof component C
    function deposit(
        bytes32 commitment,
        bytes calldata encryptedNote,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external override nonReentrant {
        // Check commitment doesn't already exist
        if (_commitmentExists(commitment)) {
            revert CommitmentAlreadyExists();
        }

        // Verify ZK proof
        // Public inputs: [commitment, denomination (if fixed)]
        uint256[] memory publicInputs = new uint256[](DENOMINATION > 0 ? 2 : 1);
        publicInputs[0] = uint256(commitment);
        if (DENOMINATION > 0) {
            publicInputs[1] = DENOMINATION;
        }

        bool proofValid = DEPOSIT_VERIFIER.verifyProof(proofA, proofB, proofC, publicInputs);
        if (!proofValid) {
            revert InvalidProof();
        }

        // Lock collateral (amount is proven in ZK proof, not passed here for privacy)
        // For fixed denomination, we know the amount. For variable, it's encoded in the proof.
        uint256 amountToLock = DENOMINATION > 0 ? DENOMINATION : _extractAmountFromProof(publicInputs);

        // Transfer from user to this contract first, then to CollateralManager
        address underlyingToken = COLLATERAL_MANAGER.getUnderlyingToken(address(this));
        require(IERC20(underlyingToken).transferFrom(msg.sender, address(this), amountToLock), "Transfer failed");
        IERC20(underlyingToken).approve(address(COLLATERAL_MANAGER), amountToLock);

        bool locked = COLLATERAL_MANAGER.lockCollateral(address(this), amountToLock, commitment);
        if (!locked) {
            revert TransferFailed();
        }

        // Insert commitment into Merkle tree
        uint256 index = commitmentTree.insert(commitment);
        commitmentIndex[commitment] = index;

        // Emit events (no amounts or addresses)
        emit NoteCommitted(commitment, index, encryptedNote);
        emit Deposit(commitment);
    }

    // ============ Transfer ============

    /// @notice Transfer confidential tokens
    /// @param inputNullifiers Nullifiers of input notes being spent
    /// @param outputCommitments Commitments of new output notes
    /// @param merkleRoot Merkle root proving input notes exist
    /// @param encryptedNotes Encrypted note data for recipients
    /// @param proofA Groth16 proof component A
    /// @param proofB Groth16 proof component B
    /// @param proofC Groth16 proof component C
    function transfer(
        bytes32[] calldata inputNullifiers,
        bytes32[] calldata outputCommitments,
        bytes32 merkleRoot,
        bytes[] calldata encryptedNotes,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external override nonReentrant {
        _validateTransferInputs(inputNullifiers, outputCommitments, encryptedNotes, merkleRoot);

        _verifyTransferProof(inputNullifiers, outputCommitments, merkleRoot, proofA, proofB, proofC);

        _processTransfer(inputNullifiers, outputCommitments, encryptedNotes);
    }

    /// @dev Validate transfer inputs
    function _validateTransferInputs(
        bytes32[] calldata inputNullifiers,
        bytes32[] calldata outputCommitments,
        bytes[] calldata encryptedNotes,
        bytes32 merkleRoot
    ) private view {
        if (inputNullifiers.length == 0 || outputCommitments.length == 0) {
            revert InvalidArrayLength();
        }
        if (encryptedNotes.length != outputCommitments.length) {
            revert InvalidArrayLength();
        }

        // Check nullifiers haven't been spent
        for (uint256 i; i < inputNullifiers.length;) {
            if (nullifiers[inputNullifiers[i]]) {
                revert NullifierAlreadySpent();
            }
            unchecked {
                ++i;
            }
        }

        // Check commitments don't exist
        for (uint256 i; i < outputCommitments.length;) {
            if (_commitmentExists(outputCommitments[i])) {
                revert CommitmentAlreadyExists();
            }
            unchecked {
                ++i;
            }
        }

        // Verify Merkle root is valid
        if (merkleRoot != commitmentTree.root) {
            revert InvalidMerkleRoot();
        }
    }

    /// @dev Verify transfer ZK proof
    function _verifyTransferProof(
        bytes32[] calldata inputNullifiers,
        bytes32[] calldata outputCommitments,
        bytes32 merkleRoot,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) private view {
        uint256[] memory publicInputs = _buildTransferPublicInputs(
            inputNullifiers,
            outputCommitments,
            merkleRoot
        );

        if (!TRANSFER_VERIFIER.verifyProof(proofA, proofB, proofC, publicInputs)) {
            revert InvalidProof();
        }
    }

    /// @dev Build public inputs for transfer proof
    function _buildTransferPublicInputs(
        bytes32[] calldata inputNullifiers,
        bytes32[] calldata outputCommitments,
        bytes32 merkleRoot
    ) private pure returns (uint256[] memory) {
        uint256[] memory publicInputs = new uint256[](
            inputNullifiers.length + outputCommitments.length + 1
        );

        uint256 idx;
        for (uint256 i; i < inputNullifiers.length;) {
            publicInputs[idx++] = uint256(inputNullifiers[i]);
            unchecked {
                ++i;
            }
        }
        for (uint256 i; i < outputCommitments.length;) {
            publicInputs[idx++] = uint256(outputCommitments[i]);
            unchecked {
                ++i;
            }
        }
        publicInputs[idx] = uint256(merkleRoot);

        return publicInputs;
    }

    /// @dev Process transfer (mark nullifiers spent, insert commitments)
    function _processTransfer(
        bytes32[] calldata inputNullifiers,
        bytes32[] calldata outputCommitments,
        bytes[] calldata encryptedNotes
    ) private {
        // Mark nullifiers as spent
        for (uint256 i; i < inputNullifiers.length;) {
            nullifiers[inputNullifiers[i]] = true;
            emit NullifierSpent(inputNullifiers[i]);
            unchecked {
                ++i;
            }
        }

        // Insert new commitments
        for (uint256 i; i < outputCommitments.length;) {
            uint256 index = commitmentTree.insert(outputCommitments[i]);
            commitmentIndex[outputCommitments[i]] = index;
            emit NoteCommitted(outputCommitments[i], index, encryptedNotes[i]);
            unchecked {
                ++i;
            }
        }
    }

    // ============ Withdraw (Burn) ============

    /// @notice Withdraw ERC20 tokens by burning a confidential note
    /// @param nullifier Nullifier of the note being spent
    /// @param recipient Address to receive the ERC20 tokens
    /// @param proofA Groth16 proof component A
    /// @param proofB Groth16 proof component B
    /// @param proofC Groth16 proof component C
    function withdraw(
        bytes32 nullifier,
        address recipient,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external override nonReentrant {
        // Check nullifier hasn't been spent
        if (nullifiers[nullifier]) {
            revert NullifierAlreadySpent();
        }

        // Verify ZK proof
        // Public inputs: [nullifier, recipient, merkleRoot]
        uint256[] memory publicInputs = new uint256[](3);
        publicInputs[0] = uint256(nullifier);
        publicInputs[1] = uint256(uint160(recipient));
        publicInputs[2] = uint256(commitmentTree.root);

        bool proofValid = WITHDRAW_VERIFIER.verifyProof(proofA, proofB, proofC, publicInputs);
        if (!proofValid) {
            revert InvalidProof();
        }

        // Mark nullifier as spent
        nullifiers[nullifier] = true;
        emit NullifierSpent(nullifier);
        emit Withdrawal(nullifier);

        // Release collateral
        // Amount is proven in ZK proof (extracted from proof or fixed denomination)
        uint256 amountToRelease = DENOMINATION > 0 ? DENOMINATION : _extractAmountFromProof(publicInputs);

        bool released = COLLATERAL_MANAGER.releaseCollateral(
            address(this),
            recipient,
            amountToRelease,
            nullifier
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

    // ============ Internal Functions ============

    /// @notice Extract amount from ZK proof public inputs
    /// @dev This is a placeholder - actual implementation depends on circuit design
    /// @param publicInputs The public inputs array
    /// @return amount The extracted amount
    function _extractAmountFromProof(uint256[] memory publicInputs) private pure returns (uint256 amount) {
        // In a real implementation, the amount would be included in public inputs
        // or derived from the proof structure based on the circuit design
        // For now, return a placeholder (circuits must be designed to expose this)
        if (publicInputs.length > 1) {
            return publicInputs[1];
        }
        return 0;
    }
}
