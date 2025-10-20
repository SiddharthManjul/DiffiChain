pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/mux1.circom";

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
        pathIndices[i] * (1 - pathIndices[i]) === 0;

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

template Withdraw() {
    var MERKLE_TREE_LEVELS = 20;
    var MAX_AMOUNT = 18446744073709551615;

    signal input secret;
    signal input nullifier;

    signal input pathElements[MERKLE_TREE_LEVELS];
    signal input pathIndices[MERKLE_TREE_LEVELS];

    signal input merkleRoot;
    signal input amount;
    signal input recipient;

    signal output commitment;
    signal output nullifierHash;

    component amountGreaterThanZero = GreaterThan(252);
    amountGreaterThanZero.in[0] <== amount;
    amountGreaterThanZero.in[1] <== 0;
    amountGreaterThanZero.out === 1;

    component amountLessThanMax = LessThan(252);
    amountLessThanMax.in[0] <== amount;
    amountLessThanMax.in[1] <== MAX_AMOUNT;
    amountLessThanMax.out === 1;

    component commitmentHasher = Poseidon(3);
    commitmentHasher.inputs[0] <== amount;
    commitmentHasher.inputs[1] <== secret;
    commitmentHasher.inputs[2] <== nullifier;
    commitment <== commitmentHasher.out;

    component merkleProof = MerkleTreeInclusionProof(MERKLE_TREE_LEVELS);
    merkleProof.leaf <== commitment;
    for (var i = 0; i < MERKLE_TREE_LEVELS; i++) {
        merkleProof.pathElements[i] <== pathElements[i];
        merkleProof.pathIndices[i] <== pathIndices[i];
    }

    merkleProof.root === merkleRoot;

    component nullifierHasher = Poseidon(1);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHash <== nullifierHasher.out;

    var MAX_ADDRESS = 1461501637330902918203684832716283019655932542975;

    component recipientInRange = LessThan(252);
    recipientInRange.in[0] <== recipient;
    recipientInRange.in[1] <== MAX_ADDRESS;
    recipientInRange.out === 1;
}

component main {public [merkleRoot, amount, recipient]} = Withdraw();

