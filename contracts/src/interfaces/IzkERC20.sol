// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IzkERC20
/// @notice Interface for confidential ERC20 tokens using zero-knowledge proofs
/// @dev Implements note-based UTXO model for privacy
interface IzkERC20 {
    /// @notice Represents a confidential note
    struct Note {
        bytes32 commitment; // Hash of (amount, secret)
        bytes32 nullifier;  // Unique identifier to prevent double-spending
    }

    /// @notice Emitted when a new note is created
    event NoteCommitted(bytes32 indexed commitment, address indexed ephemeralAddress);

    /// @notice Emitted when a note is spent
    event NullifierSpent(bytes32 indexed nullifier);

    /// @notice Emitted when tokens are deposited
    event Deposit(bytes32 indexed commitment, uint256 timestamp);

    /// @notice Emitted when tokens are withdrawn
    event Withdrawal(bytes32 indexed nullifier, address indexed recipient, uint256 timestamp);

    /// @notice Deposit ERC20 tokens and mint confidential note
    /// @param commitment The commitment of the new note
    /// @param amount The amount to deposit
    /// @param proof The zero-knowledge proof
    function deposit(bytes32 commitment, uint256 amount, bytes calldata proof) external;

    /// @notice Transfer confidential tokens to a new note
    /// @param inputNullifier The nullifier of the input note being spent
    /// @param outputCommitment The commitment of the new output note
    /// @param merkleRoot The Merkle root proving input note existence
    /// @param proof The zero-knowledge proof
    function transfer(
        bytes32 inputNullifier,
        bytes32 outputCommitment,
        bytes32 merkleRoot,
        bytes calldata proof
    ) external;

    /// @notice Withdraw ERC20 tokens by burning a confidential note
    /// @param nullifier The nullifier of the note being spent
    /// @param recipient The address to receive the withdrawn tokens
    /// @param amount The amount to withdraw
    /// @param proof The zero-knowledge proof
    function withdraw(bytes32 nullifier, address recipient, uint256 amount, bytes calldata proof) external;

    /// @notice Check if a commitment exists
    function commitments(bytes32 commitment) external view returns (bool);

    /// @notice Check if a nullifier has been spent
    function nullifiers(bytes32 nullifier) external view returns (bool);

    /// @notice Get the current Merkle root
    function getMerkleRoot() external view returns (bytes32);
}
