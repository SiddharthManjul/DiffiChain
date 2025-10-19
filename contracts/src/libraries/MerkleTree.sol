// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MerkleTree
/// @notice Incremental Merkle tree for storing note commitments
/// @dev Uses Poseidon hash (or keccak256 as placeholder) for ZK-friendly operations
library MerkleTree {
    /// @notice Merkle tree depth (supports 2^20 = ~1M notes)
    uint256 public constant TREE_DEPTH = 20;

    /// @notice Maximum number of leaves in the tree
    uint256 public constant MAX_LEAVES = 2 ** TREE_DEPTH;

    /// @notice Zero value for empty nodes
    bytes32 public constant ZERO_VALUE = bytes32(0);

    /// @notice Merkle tree state
    struct Tree {
        uint256 nextIndex;
        mapping(uint256 => bytes32) leaves;
        mapping(uint256 => mapping(uint256 => bytes32)) branches;
        bytes32 root;
    }

    /// @notice Hash function (placeholder - should use Poseidon in production)
    /// @param left Left node
    /// @param right Right node
    /// @return result Hash of left and right
    function hashLeftRight(bytes32 left, bytes32 right) internal pure returns (bytes32 result) {
        // TODO: Replace with Poseidon hash for ZK-friendliness
        // For now, using keccak256 as placeholder
        result = keccak256(abi.encodePacked(left, right));
    }

    /// @notice Get zero value for a given level
    /// @param level The tree level
    /// @return zero The zero value at that level
    function zeros(uint256 level) internal pure returns (bytes32 zero) {
        // Precomputed zero values for each level
        // In production, compute: zeros[i] = hash(zeros[i-1], zeros[i-1])
        if (level == 0) return ZERO_VALUE;
        if (level == 1) return keccak256(abi.encodePacked(ZERO_VALUE, ZERO_VALUE));

        // Simplified: recursively compute
        bytes32 subZero = zeros(level - 1);
        return hashLeftRight(subZero, subZero);
    }

    /// @notice Initialize the Merkle tree
    /// @param self The tree instance
    function initialize(Tree storage self) internal {
        self.nextIndex = 0;
        self.root = zeros(TREE_DEPTH);
    }

    /// @notice Insert a leaf into the Merkle tree
    /// @param self The tree instance
    /// @param leaf The leaf value to insert
    /// @return index The index where the leaf was inserted
    function insert(Tree storage self, bytes32 leaf) internal returns (uint256 index) {
        require(self.nextIndex < MAX_LEAVES, "MerkleTree: tree is full");

        index = self.nextIndex;
        self.leaves[index] = leaf;

        bytes32 currentHash = leaf;
        uint256 currentIndex = index;

        for (uint256 i = 0; i < TREE_DEPTH; i++) {
            // Store branch node
            self.branches[i][currentIndex] = currentHash;

            // Determine sibling
            bytes32 sibling;
            if (currentIndex % 2 == 0) {
                // We're left child, sibling is right (might be zero)
                uint256 siblingIndex = currentIndex + 1;
                sibling = self.branches[i][siblingIndex];
                if (sibling == bytes32(0)) {
                    sibling = zeros(i);
                }
                currentHash = hashLeftRight(currentHash, sibling);
            } else {
                // We're right child, sibling is left
                uint256 siblingIndex = currentIndex - 1;
                sibling = self.branches[i][siblingIndex];
                currentHash = hashLeftRight(sibling, currentHash);
            }

            currentIndex = currentIndex / 2;
        }

        self.root = currentHash;
        self.nextIndex++;
    }

    /// @notice Verify a Merkle proof
    /// @param root The Merkle root to verify against
    /// @param leaf The leaf value
    /// @param index The index of the leaf
    /// @param path The Merkle path (sibling hashes)
    /// @return valid True if the proof is valid
    function verify(
        bytes32 root,
        bytes32 leaf,
        uint256 index,
        bytes32[] memory path
    ) internal pure returns (bool valid) {
        require(path.length == TREE_DEPTH, "MerkleTree: invalid path length");

        bytes32 currentHash = leaf;
        uint256 currentIndex = index;

        for (uint256 i = 0; i < TREE_DEPTH; i++) {
            bytes32 sibling = path[i];

            if (currentIndex % 2 == 0) {
                // We're left child
                currentHash = hashLeftRight(currentHash, sibling);
            } else {
                // We're right child
                currentHash = hashLeftRight(sibling, currentHash);
            }

            currentIndex = currentIndex / 2;
        }

        return currentHash == root;
    }

    /// @notice Get the current root
    /// @param self The tree instance
    /// @return root The current Merkle root
    function getRoot(Tree storage self) internal view returns (bytes32 root) {
        return self.root;
    }

    /// @notice Get the next available index
    /// @param self The tree instance
    /// @return index The next index
    function getNextIndex(Tree storage self) internal view returns (uint256 index) {
        return self.nextIndex;
    }

    /// @notice Check if a leaf exists at a given index
    /// @param self The tree instance
    /// @param index The index to check
    /// @return exists True if a leaf exists at that index
    function leafExists(Tree storage self, uint256 index) internal view returns (bool exists) {
        return index < self.nextIndex;
    }
}
