pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/mux1.circom";
include "../node_modules/circomlib/circuits/bitify.circom";

/*
 * transfer.circom
 *
 * Purpose: Prove valid, private transfer between notes with support for splitting/merging.
 *          Demonstrates ownership of input notes via Merkle tree inclusion proof,
 *          and creates new output notes while maintaining balance.
 *
 * Privacy Guarantees:
 * - Input amounts, secrets, and nullifiers remain private
 * - Output amounts and secrets remain private
 * - Only commitments and nullifierHashes are public
 * - No linkability between input and output notes
 *
 * Security Constraints:
 * - Input notes must exist in Merkle tree (proves ownership)
 * - Knowledge of secrets for all input notes required
 * - Sum of inputs = sum of outputs (no inflation/deflation)
 * - All commitments properly formed
 * - All nullifiers properly computed (prevents double-spending)
 */

template MerkleTreeInclusionProof(levels) {
    signal input leaf;
    signal input pathElements[levels];
    signal input pathIndices[levels];
    signal output root;

    component hashers[levels];
    component mux[levels];

    signal levelHashes[levels + 1];
    levelHashes[0] <== leaf;

    for (var i = 0; i < levels; i++) {
        // Determine if current node is left or right child
        pathIndices[i] * (1 - pathIndices[i]) === 0; // Ensure binary

        mux[i] = MultiMux1(2);
        mux[i].c[0][0] <== levelHashes[i];
        mux[i].c[0][1] <== pathElements[i];
        mux[i].c[1][0] <== pathElements[i];
        mux[i].c[1][1] <== levelHashes[i];
        mux[i].s <== pathIndices[i];

        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== mux[i].out[0];
        hashers[i].inputs[1] <== mux[i].out[1];

        levelHashes[i + 1] <== hashers[i].out;
    }

    root <== levelHashes[levels];
}

template Transfer() {
    // Configuration
    var MERKLE_TREE_LEVELS = 20;  // Supports ~1M notes (2^20)
    var NUM_INPUTS = 2;            // Number of input notes to consume
    var NUM_OUTPUTS = 2;           // Number of output notes to create

    // ============================================
    // PRIVATE INPUTS (never revealed on-chain)
    // ============================================
    // Input notes (being spent)
    signal input inputAmounts[NUM_INPUTS];
    signal input inputSecrets[NUM_INPUTS];
    signal input inputNullifiers[NUM_INPUTS];

    // Merkle tree paths for each input note
    signal input inputPathElements[NUM_INPUTS][MERKLE_TREE_LEVELS];
    signal input inputPathIndices[NUM_INPUTS][MERKLE_TREE_LEVELS];

    // Output notes (being created)
    signal input outputAmounts[NUM_OUTPUTS];
    signal input outputSecrets[NUM_OUTPUTS];
    signal input outputNullifiers[NUM_OUTPUTS];

    // ============================================
    // PUBLIC INPUTS/OUTPUTS
    // ============================================
    signal input merkleRoot;  // Public: Current state of note tree

    signal output inputNullifierHashes[NUM_INPUTS];   // To mark inputs as spent
    signal output outputCommitments[NUM_OUTPUTS];     // New notes to add to tree

    // ============================================
    // CONSTRAINT 1: Merkle Tree Inclusion Proofs
    // ============================================
    // Prove that each input note exists in the Merkle tree
    component inputCommitmentHashers[NUM_INPUTS];
    component merkleProofs[NUM_INPUTS];

    for (var i = 0; i < NUM_INPUTS; i++) {
        // Recompute input note commitment
        inputCommitmentHashers[i] = Poseidon(3);
        inputCommitmentHashers[i].inputs[0] <== inputAmounts[i];
        inputCommitmentHashers[i].inputs[1] <== inputSecrets[i];
        inputCommitmentHashers[i].inputs[2] <== inputNullifiers[i];

        // Verify commitment exists in Merkle tree
        merkleProofs[i] = MerkleTreeInclusionProof(MERKLE_TREE_LEVELS);
        merkleProofs[i].leaf <== inputCommitmentHashers[i].out;
        for (var j = 0; j < MERKLE_TREE_LEVELS; j++) {
            merkleProofs[i].pathElements[j] <== inputPathElements[i][j];
            merkleProofs[i].pathIndices[j] <== inputPathIndices[i][j];
        }

        // Ensure computed root matches public merkleRoot
        merkleProofs[i].root === merkleRoot;
    }

    // ============================================
    // CONSTRAINT 2: Input Nullifier Hashes
    // ============================================
    // Generate nullifier hashes to prevent double-spending
    component inputNullifierHashers[NUM_INPUTS];

    for (var i = 0; i < NUM_INPUTS; i++) {
        inputNullifierHashers[i] = Poseidon(1);
        inputNullifierHashers[i].inputs[0] <== inputNullifiers[i];
        inputNullifierHashes[i] <== inputNullifierHashers[i].out;
    }

    // ============================================
    // CONSTRAINT 3: Output Commitments
    // ============================================
    // Generate commitments for new output notes
    component outputCommitmentHashers[NUM_OUTPUTS];

    for (var i = 0; i < NUM_OUTPUTS; i++) {
        outputCommitmentHashers[i] = Poseidon(3);
        outputCommitmentHashers[i].inputs[0] <== outputAmounts[i];
        outputCommitmentHashers[i].inputs[1] <== outputSecrets[i];
        outputCommitmentHashers[i].inputs[2] <== outputNullifiers[i];
        outputCommitments[i] <== outputCommitmentHashers[i].out;
    }

    // ============================================
    // CONSTRAINT 4: Balance Conservation
    // ============================================
    // Sum of input amounts must equal sum of output amounts
    signal inputSum;
    signal outputSum;

    // Calculate input sum
    signal inputPartialSums[NUM_INPUTS];
    inputPartialSums[0] <== inputAmounts[0];
    for (var i = 1; i < NUM_INPUTS; i++) {
        inputPartialSums[i] <== inputPartialSums[i-1] + inputAmounts[i];
    }
    inputSum <== inputPartialSums[NUM_INPUTS - 1];

    // Calculate output sum
    signal outputPartialSums[NUM_OUTPUTS];
    outputPartialSums[0] <== outputAmounts[0];
    for (var i = 1; i < NUM_OUTPUTS; i++) {
        outputPartialSums[i] <== outputPartialSums[i-1] + outputAmounts[i];
    }
    outputSum <== outputPartialSums[NUM_OUTPUTS - 1];

    // Enforce balance
    inputSum === outputSum;

    // ============================================
    // CONSTRAINT 5: Amount Range Checks
    // ============================================
    // Ensure all amounts are valid (non-negative and below max)
    var MAX_AMOUNT = 18446744073709551615; // 2^64 - 1

    component inputAmountChecks[NUM_INPUTS];
    for (var i = 0; i < NUM_INPUTS; i++) {
        inputAmountChecks[i] = LessThan(252);
        inputAmountChecks[i].in[0] <== inputAmounts[i];
        inputAmountChecks[i].in[1] <== MAX_AMOUNT;
        inputAmountChecks[i].out === 1;
    }

    component outputAmountChecks[NUM_OUTPUTS];
    for (var i = 0; i < NUM_OUTPUTS; i++) {
        outputAmountChecks[i] = LessThan(252);
        outputAmountChecks[i].in[0] <== outputAmounts[i];
        outputAmountChecks[i].in[1] <== MAX_AMOUNT;
        outputAmountChecks[i].out === 1;
    }

    // ============================================
    // CONSTRAINT 6: Nullifier Uniqueness
    // ============================================
    // Ensure all input nullifiers are distinct (prevent same note used twice in one tx)
    component nullifierEquality = IsEqual();
    nullifierEquality.in[0] <== inputNullifiers[0];
    nullifierEquality.in[1] <== inputNullifiers[1];
    nullifierEquality.out === 0; // Must be different

    // Ensure all output nullifiers are distinct
    component outputNullifierEquality = IsEqual();
    outputNullifierEquality.in[0] <== outputNullifiers[0];
    outputNullifierEquality.in[1] <== outputNullifiers[1];
    outputNullifierEquality.out === 0; // Must be different
}

// Main component for circuit compilation
component main {public [merkleRoot]} = Transfer();

/*
 * USAGE NOTES:
 *
 * Public Signals (in order for Groth16 verifier):
 * 1. merkleRoot (input)
 * 2. inputNullifierHashes[0] (output)
 * 3. inputNullifierHashes[1] (output)
 * 4. outputCommitments[0] (output)
 * 5. outputCommitments[1] (output)
 *
 * When generating proofs with snarkjs:
 *
 * Input JSON format:
 * {
 *   "inputAmounts": ["1000000000000000000", "500000000000000000"],
 *   "inputSecrets": ["123...", "456..."],
 *   "inputNullifiers": ["789...", "012..."],
 *   "inputPathElements": [[...], [...]],  // 20-level paths
 *   "inputPathIndices": [[0,1,0,...], [1,0,1,...]],
 *   "outputAmounts": ["800000000000000000", "700000000000000000"],
 *   "outputSecrets": ["345...", "678..."],
 *   "outputNullifiers": ["901...", "234..."],
 *   "merkleRoot": "567..."
 * }
 *
 * Transfer Use Cases:
 * - Simple transfer: Input[A] → Output[B, Change]
 * - Merge notes: Input[A, B] → Output[C, 0]
 * - Split note: Input[A, 0] → Output[B, C]
 *
 * Integration with Solidity:
 * - Contract verifies proof with public signals
 * - Contract marks inputNullifierHashes as spent
 * - Contract adds outputCommitments to Merkle tree
 * - Contract updates merkleRoot
 *
 * Security Recommendations:
 * - Always use fresh nullifiers for outputs
 * - Verify Merkle root is current before generating proof
 * - Use zero amounts for unused input/output slots
 * - Never reuse secrets across notes
 */
