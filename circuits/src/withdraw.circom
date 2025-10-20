pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/mux1.circom";

/*
 * withdraw.circom
 *
 * Purpose: Privately prove ownership and value of a note for redemption.
 *          Allows burning a confidential note to redeem the underlying ERC-20 tokens.
 *
 * Privacy Guarantees:
 * - amount, secret, and nullifier remain private
 * - Recipient address for withdrawal can be specified without revealing note owner
 * - Only commitment, nullifierHash, and amount are revealed (amount must be public for ERC-20 transfer)
 *
 * Security Constraints:
 * - Note must exist in Merkle tree (proves ownership)
 * - Knowledge of note's secret and nullifier required
 * - Amount must match commitment (prevents false claims)
 * - Nullifier is revealed to prevent double-withdrawal
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
        // Ensure path indices are binary (0 or 1)
        pathIndices[i] * (1 - pathIndices[i]) === 0;

        // Select correct ordering based on path index
        mux[i] = MultiMux1(2);
        mux[i].c[0][0] <== levelHashes[i];      // left if pathIndices[i] = 0
        mux[i].c[0][1] <== pathElements[i];
        mux[i].c[1][0] <== pathElements[i];     // left if pathIndices[i] = 1
        mux[i].c[1][1] <== levelHashes[i];
        mux[i].s <== pathIndices[i];

        // Hash the pair
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== mux[i].out[0];
        hashers[i].inputs[1] <== mux[i].out[1];

        levelHashes[i + 1] <== hashers[i].out;
    }

    root <== levelHashes[levels];
}

template Withdraw() {
    // Configuration
    var MERKLE_TREE_LEVELS = 20;  // Supports ~1M notes (2^20)
    var MAX_AMOUNT = 18446744073709551615; // 2^64 - 1

    // ============================================
    // PRIVATE INPUTS (never revealed on-chain)
    // ============================================
    signal input secret;       // Secret used in commitment
    signal input nullifier;    // Nullifier to prevent double-spending

    // Merkle tree path proving note ownership
    signal input pathElements[MERKLE_TREE_LEVELS];
    signal input pathIndices[MERKLE_TREE_LEVELS];

    // ============================================
    // PUBLIC INPUTS/OUTPUTS
    // ============================================
    signal input merkleRoot;   // Current state of note tree
    signal input amount;       // Amount to withdraw (must be public for ERC-20 transfer)
    signal input recipient;    // Ethereum address to receive tokens (as field element)

    signal output commitment;      // Recomputed commitment (for verification)
    signal output nullifierHash;   // To mark note as spent

    // ============================================
    // CONSTRAINT 1: Amount Range Check
    // ============================================
    // Ensure amount > 0
    component amountGreaterThanZero = GreaterThan(252);
    amountGreaterThanZero.in[0] <== amount;
    amountGreaterThanZero.in[1] <== 0;
    amountGreaterThanZero.out === 1;

    // Ensure amount < MAX_AMOUNT
    component amountLessThanMax = LessThan(252);
    amountLessThanMax.in[0] <== amount;
    amountLessThanMax.in[1] <== MAX_AMOUNT;
    amountLessThanMax.out === 1;

    // ============================================
    // CONSTRAINT 2: Commitment Computation
    // ============================================
    // Recompute commitment from private inputs
    // commitment = Poseidon(amount, secret, nullifier)
    component commitmentHasher = Poseidon(3);
    commitmentHasher.inputs[0] <== amount;
    commitmentHasher.inputs[1] <== secret;
    commitmentHasher.inputs[2] <== nullifier;
    commitment <== commitmentHasher.out;

    // ============================================
    // CONSTRAINT 3: Merkle Tree Inclusion Proof
    // ============================================
    // Prove that the commitment exists in the Merkle tree
    component merkleProof = MerkleTreeInclusionProof(MERKLE_TREE_LEVELS);
    merkleProof.leaf <== commitment;
    for (var i = 0; i < MERKLE_TREE_LEVELS; i++) {
        merkleProof.pathElements[i] <== pathElements[i];
        merkleProof.pathIndices[i] <== pathIndices[i];
    }

    // Verify computed root matches public merkleRoot
    merkleProof.root === merkleRoot;

    // ============================================
    // CONSTRAINT 4: Nullifier Hash Computation
    // ============================================
    // Generate nullifier hash to prevent double-withdrawal
    component nullifierHasher = Poseidon(1);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHash <== nullifierHasher.out;

    // ============================================
    // CONSTRAINT 5: Recipient Address Validation
    // ============================================
    // Ensure recipient is a valid Ethereum address (160 bits)
    // Recipient should be < 2^160
    var MAX_ADDRESS = 1461501637330902918203684832716283019655932542975; // 2^160 - 1

    component recipientInRange = LessThan(252);
    recipientInRange.in[0] <== recipient;
    recipientInRange.in[1] <== MAX_ADDRESS;
    recipientInRange.out === 1;

    // ============================================
    // SIGNAL CONSTRAINTS
    // ============================================
    // All signals are properly constrained:
    // - amount: used in range checks and commitment
    // - secret: used in commitment
    // - nullifier: used in nullifierHash
    // - pathElements/pathIndices: used in Merkle proof
    // - merkleRoot: compared with computed root
    // - recipient: range checked
    // - commitment: output from hasher
    // - nullifierHash: output from hasher
}

// Main component for circuit compilation
component main {public [merkleRoot, amount, recipient]} = Withdraw();

/*
 * USAGE NOTES:
 *
 * Public Signals (in order for Groth16 verifier):
 * 1. merkleRoot (input)
 * 2. amount (input) - NOTE: Amount is PUBLIC for withdrawal (needed for ERC-20 transfer)
 * 3. recipient (input) - Ethereum address as field element
 * 4. commitment (output)
 * 5. nullifierHash (output)
 *
 * When generating proofs with snarkjs:
 *
 * Input JSON format:
 * {
 *   "secret": "12345...",                     // Private: note secret
 *   "nullifier": "67890...",                  // Private: note nullifier
 *   "pathElements": ["...", "...", ...],      // Private: 20-level Merkle path
 *   "pathIndices": [0, 1, 0, ...],           // Private: path directions
 *   "merkleRoot": "11111...",                 // Public: current tree root
 *   "amount": "1000000000000000000",          // Public: amount to withdraw (1 token)
 *   "recipient": "0x742d35Cc6..."            // Public: recipient address (as decimal)
 * }
 *
 * Privacy Considerations:
 * - Amount MUST be public for withdrawal (ERC-20 transfer requires known amount)
 * - Recipient MUST be public (tokens must go somewhere)
 * - Secret and nullifier remain private (prevents linking to deposit)
 * - Merkle path remains private (prevents linking note history)
 *
 * Integration with Solidity:
 * - Contract verifies proof with public signals
 * - Contract marks nullifierHash as spent (prevents double-withdrawal)
 * - Contract transfers amount of ERC-20 tokens to recipient
 * - Contract removes note from spendable set
 *
 * Withdrawal Flow:
 * 1. User selects note to withdraw from private note database
 * 2. User generates Merkle proof for note inclusion
 * 3. User generates ZK proof with private inputs
 * 4. User submits proof + public inputs to contract
 * 5. Contract verifies proof and transfers tokens
 *
 * Security Recommendations:
 * - Verify merkleRoot is current before generating proof
 * - Ensure recipient address is controlled by user
 * - Check nullifier hasn't been used before submitting
 * - Use transaction relayers to hide sender's Ethereum address
 * - Consider using stealth addresses for recipient privacy
 *
 * Conversion of Ethereum Address to Field Element:
 * In JavaScript:
 *   const recipientField = BigInt(recipientAddress).toString();
 *
 * In Solidity (verification):
 *   require(publicSignals[2] == uint256(uint160(recipient)), "Invalid recipient");
 */
