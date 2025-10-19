// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IzkERC20
/// @notice Interface for confidential ERC20 tokens using zero-knowledge proofs
/// @dev Implements note-based UTXO model for privacy
interface IzkERC20 {
    /// @notice Emitted when a new note commitment is created
    /// @param commitment The hash of (amount, secret) - hides the value
    /// @param index The index in the Merkle tree
    /// @param encryptedNote Optional encrypted note data for recipient
    event NoteCommitted(bytes32 indexed commitment, uint256 indexed index, bytes encryptedNote);

    /// @notice Emitted when a note is spent (nullifier revealed)
    /// @param nullifier The unique nullifier preventing double-spending
    event NullifierSpent(bytes32 indexed nullifier);

    /// @notice Emitted when tokens are deposited (minting)
    /// @param commitment The commitment of the newly minted note
    event Deposit(bytes32 indexed commitment);

    /// @notice Emitted when tokens are withdrawn
    /// @param nullifier The nullifier of the burned note
    event Withdrawal(bytes32 indexed nullifier);

    /// @notice Deposit ERC20 tokens and mint a confidential note
    /// @param commitment The commitment of the new note (hash of amount + secret)
    /// @param encryptedNote Encrypted note data for the recipient
    /// @param proofA Groth16 proof component A
    /// @param proofB Groth16 proof component B
    /// @param proofC Groth16 proof component C
    /// @dev Requires prior ERC20 approval. Verifies ZK proof of valid deposit.
    function deposit(
        bytes32 commitment,
        bytes calldata encryptedNote,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external;

    /// @notice Transfer confidential tokens by spending input notes and creating output notes
    /// @param inputNullifiers Array of nullifiers for notes being spent
    /// @param outputCommitments Array of commitments for new notes being created
    /// @param merkleRoot The Merkle root proving input notes exist
    /// @param encryptedNotes Array of encrypted note data for recipients
    /// @param proofA Groth16 proof component A
    /// @param proofB Groth16 proof component B
    /// @param proofC Groth16 proof component C
    /// @dev Verifies ZK proof that inputs are owned and outputs are valid
    function transfer(
        bytes32[] calldata inputNullifiers,
        bytes32[] calldata outputCommitments,
        bytes32 merkleRoot,
        bytes[] calldata encryptedNotes,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external;

    /// @notice Withdraw ERC20 tokens by burning a confidential note
    /// @param nullifier The nullifier of the note being spent
    /// @param recipient The address to receive the withdrawn ERC20 tokens
    /// @param proofA Groth16 proof component A
    /// @param proofB Groth16 proof component B
    /// @param proofC Groth16 proof component C
    /// @dev Verifies ZK proof of note ownership, then releases collateral
    function withdraw(
        bytes32 nullifier,
        address recipient,
        uint256[2] calldata proofA,
        uint256[2][2] calldata proofB,
        uint256[2] calldata proofC
    ) external;

    /// @notice Check if a commitment exists in the Merkle tree
    /// @param commitment The commitment to check
    /// @return exists True if the commitment exists
    function commitmentExists(bytes32 commitment) external view returns (bool exists);

    /// @notice Check if a nullifier has been spent
    /// @param nullifier The nullifier to check
    /// @return spent True if already spent
    function isNullifierSpent(bytes32 nullifier) external view returns (bool spent);

    /// @notice Get the current Merkle root
    /// @return root The current Merkle tree root
    function getMerkleRoot() external view returns (bytes32 root);

    /// @notice Get the next available commitment index
    /// @return index The next index
    function getNextIndex() external view returns (uint256 index);
}
