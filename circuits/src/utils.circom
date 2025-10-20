pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";

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

template NullifierHash() {
    signal input nullifier;
    signal output hash;

    component hasher = Poseidon(1);
    hasher.inputs[0] <== nullifier;
    hash <== hasher.out;
}

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

function MAX_TOKEN_AMOUNT() {
    return 18446744073709551615;
}

function MAX_ETH_ADDRESS() {
    return 1461501637330902918203684832716283019655932542975;
}

function SNARK_FIELD_SIZE() {
    return 21888242871839275222246405745257275088548364400416034343698204186575808495617;
}

function DEFAULT_MERKLE_LEVELS() {
    return 20;
}

