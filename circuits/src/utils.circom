pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";

/*
 * utils.circom
 *
 * Shared utility templates for DiffiChain circuits.
 * These helpers are used across deposit, transfer, and withdraw circuits.
 */

/*
 * NoteCommitment
 *
 * Generates a note commitment from amount, secret, and nullifier.
 * This is the core primitive for the UTXO note model.
 *
 * Usage:
 *   component noteCommit = NoteCommitment();
 *   noteCommit.amount <== amount;
 *   noteCommit.secret <== secret;
 *   noteCommit.nullifier <== nullifier;
 *   commitment <== noteCommit.commitment;
 */
template NoteCommitment() {
    signal input amount;
    signal input secret;
    signal input nullifier;
    signal output commitment;

    component hasher = Poseidon(3);
    hasher.inputs[0] <== amount;
    hasher.inputs[1] <== secret;
    hasher.inputs[2] <== nullifier;
    commitment <== hasher.out;
}

/*
 * NullifierHash
 *
 * Generates a nullifier hash to prevent double-spending.
 *
 * Usage:
 *   component nullHash = NullifierHash();
 *   nullHash.nullifier <== nullifier;
 *   nullifierHash <== nullHash.hash;
 */
template NullifierHash() {
    signal input nullifier;
    signal output hash;

    component hasher = Poseidon(1);
    hasher.inputs[0] <== nullifier;
    hash <== hasher.out;
}

/*
 * RangeCheck
 *
 * Ensures a value is within [min, max) range.
 * Useful for validating amounts and preventing overflow attacks.
 *
 * Usage:
 *   component rangeCheck = RangeCheck();
 *   rangeCheck.value <== amount;
 *   rangeCheck.min <== 0;
 *   rangeCheck.max <== MAX_AMOUNT;
 *   rangeCheck.valid === 1; // Constrain to be true
 */
template RangeCheck() {
    signal input value;
    signal input min;
    signal input max;
    signal output valid;

    component greaterThanMin = GreaterEqThan(252);
    greaterThanMin.in[0] <== value;
    greaterThanMin.in[1] <== min;

    component lessThanMax = LessThan(252);
    lessThanMax.in[0] <== value;
    lessThanMax.in[1] <== max;

    // Both conditions must be true
    signal both;
    both <== greaterThanMin.out * lessThanMax.out;
    valid <== both;
}

/*
 * ArraySum
 *
 * Computes the sum of an array of signals.
 * Useful for balance checks in transfers.
 *
 * Usage:
 *   component sum = ArraySum(3);
 *   sum.values[0] <== a;
 *   sum.values[1] <== b;
 *   sum.values[2] <== c;
 *   total <== sum.sum;
 */
template ArraySum(n) {
    signal input values[n];
    signal output sum;

    signal partialSums[n];
    partialSums[0] <== values[0];

    for (var i = 1; i < n; i++) {
        partialSums[i] <== partialSums[i-1] + values[i];
    }

    sum <== partialSums[n-1];
}

/*
 * EthereumAddressCheck
 *
 * Validates that a field element represents a valid Ethereum address (< 2^160).
 *
 * Usage:
 *   component addrCheck = EthereumAddressCheck();
 *   addrCheck.address <== recipientField;
 *   addrCheck.valid === 1; // Constrain to be true
 */
template EthereumAddressCheck() {
    signal input address;
    signal output valid;

    // Maximum Ethereum address value (2^160 - 1)
    var MAX_ADDRESS = 1461501637330902918203684832716283019655932542975;

    component inRange = LessThan(252);
    inRange.in[0] <== address;
    inRange.in[1] <== MAX_ADDRESS;
    valid <== inRange.out;
}

/*
 * BitwiseXOR
 *
 * Computes XOR of two field elements bit-by-bit.
 * Useful for stealth address derivation.
 *
 * Note: This is expensive in circuits. Use only when necessary.
 *
 * Usage:
 *   component xor = BitwiseXOR(160); // For addresses
 *   xor.a <== value1;
 *   xor.b <== value2;
 *   result <== xor.out;
 */
template BitwiseXOR(n) {
    signal input a;
    signal input b;
    signal output out;

    signal aBits[n];
    signal bBits[n];
    signal outBits[n];

    component aNum2Bits = Num2Bits(n);
    aNum2Bits.in <== a;

    component bNum2Bits = Num2Bits(n);
    bNum2Bits.in <== b;

    for (var i = 0; i < n; i++) {
        aBits[i] <== aNum2Bits.out[i];
        bBits[i] <== bNum2Bits.out[i];

        // XOR: a XOR b = a + b - 2*a*b
        outBits[i] <== aBits[i] + bBits[i] - 2*aBits[i]*bBits[i];
    }

    component bits2Num = Bits2Num(n);
    for (var i = 0; i < n; i++) {
        bits2Num.in[i] <== outBits[i];
    }
    out <== bits2Num.out;
}

/*
 * CONSTANTS
 *
 * Commonly used constants across circuits.
 */

// Maximum token amount (2^64 - 1, ~18.4 quintillion)
// Sufficient for most token use cases with 18 decimals
function MAX_TOKEN_AMOUNT() {
    return 18446744073709551615;
}

// Maximum Ethereum address value (2^160 - 1)
function MAX_ETH_ADDRESS() {
    return 1461501637330902918203684832716283019655932542975;
}

// Field prime for BN128 curve (used in Groth16)
function SNARK_FIELD_SIZE() {
    return 21888242871839275222246405745257275088548364400416034343698204186575808495617;
}

// Default Merkle tree depth (supports ~1M notes)
function DEFAULT_MERKLE_LEVELS() {
    return 20;
}

/*
 * USAGE NOTES:
 *
 * These utility templates are designed to be composable and reusable.
 * Import them in your main circuits as needed:
 *
 * include "./utils.circom";
 *
 * Benefits:
 * - Reduces code duplication
 * - Ensures consistent implementations
 * - Makes circuits easier to audit
 * - Simplifies maintenance and updates
 *
 * Security Recommendations:
 * - Always use NoteCommitment for creating commitments
 * - Always use NullifierHash for generating nullifier hashes
 * - Use RangeCheck for all amount validations
 * - Use EthereumAddressCheck for address validations
 */
