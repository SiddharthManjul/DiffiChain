pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";

/*
 * deposit.circom
 *
 * Purpose: Prove knowledge of (amount, secret, nullifier) that hashes to a commitment
 *          for privacy-preserving token deposits without revealing the amount.
 *
 * Privacy Guarantees:
 * - amount, secret, and nullifier remain private
 * - Only commitment and nullifierHash are public outputs
 * - No information about deposit value is leaked
 *
 * Security Constraints:
 * - amount must be > 0 (prevents zero-value spam)
 * - amount must be < MAX_VALUE (prevents overflow attacks)
 * - commitment = Poseidon(amount, secret, nullifier)
 * - nullifierHash = Poseidon(nullifier)
 */

template Deposit() {
    // Maximum allowed amount (2^64 - 1 to prevent overflow)
    // This is approximately 18.4 quintillion, sufficient for token amounts
    var MAX_AMOUNT = 18446744073709551615;

    // ============================================
    // PRIVATE INPUTS (never revealed on-chain)
    // ============================================
    signal input amount;        // Token amount to deposit
    signal input secret;        // Random secret for commitment
    signal input nullifier;     // Unique nullifier to prevent double-spending

    // ============================================
    // PUBLIC OUTPUTS (published on-chain)
    // ============================================
    signal output commitment;      // Hash of (amount, secret, nullifier)
    signal output nullifierHash;   // Hash of nullifier (to mark as spent later)

    // ============================================
    // CONSTRAINT 1: Amount Range Check
    // ============================================
    // Ensure amount > 0
    component amountGreaterThanZero = GreaterThan(252);
    amountGreaterThanZero.in[0] <== amount;
    amountGreaterThanZero.in[1] <== 0;
    amountGreaterThanZero.out === 1;

    // Ensure amount < MAX_AMOUNT (prevent overflow)
    component amountLessThanMax = LessThan(252);
    amountLessThanMax.in[0] <== amount;
    amountLessThanMax.in[1] <== MAX_AMOUNT;
    amountLessThanMax.out === 1;

    // ============================================
    // CONSTRAINT 2: Commitment Computation
    // ============================================
    // commitment = Poseidon(amount, secret, nullifier)
    // Poseidon is a ZK-friendly hash function optimized for circuit efficiency
    component commitmentHasher = Poseidon(3);
    commitmentHasher.inputs[0] <== amount;
    commitmentHasher.inputs[1] <== secret;
    commitmentHasher.inputs[2] <== nullifier;
    commitment <== commitmentHasher.out;

    // ============================================
    // CONSTRAINT 3: Nullifier Hash Computation
    // ============================================
    // nullifierHash = Poseidon(nullifier)
    // This will be revealed when the note is spent to prevent double-spending
    component nullifierHasher = Poseidon(1);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHash <== nullifierHasher.out;

    // ============================================
    // SIGNAL CONSTRAINTS
    // ============================================
    // Ensure all signals are properly constrained (no underconstraints)
    // All inputs are used in the computations above
    // All outputs are assigned from constraint results
    // This prevents malicious proof generation
}

// Main component for circuit compilation
component main = Deposit();

/*
 * USAGE NOTES:
 *
 * Public Signals (in order for Groth16 verifier):
 * 1. commitment (output)
 * 2. nullifierHash (output)
 *
 * When generating proofs with snarkjs:
 *
 * Input JSON format:
 * {
 *   "amount": "1000000000000000000",  // 1 token (18 decimals)
 *   "secret": "12345...",              // Random 252-bit number
 *   "nullifier": "67890..."            // Random 252-bit number
 * }
 *
 * The proof will demonstrate knowledge of these values without revealing them.
 * The verifier only sees commitment and nullifierHash.
 *
 * Integration with Solidity:
 * - Contract stores commitments in mapping
 * - Contract tracks nullifierHashes to prevent double-spending
 * - Contract calls DepositVerifier.verifyProof(proof, [commitment, nullifierHash])
 *
 * Security Recommendations:
 * - Generate secret and nullifier using cryptographically secure randomness
 * - Never reuse nullifiers across different notes
 * - Store secret securely (needed for spending the note later)
 */
