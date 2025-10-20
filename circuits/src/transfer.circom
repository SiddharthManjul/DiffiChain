pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/mux1.circom";
include "../node_modules/circomlib/circuits/bitify.circom";

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

template Transfer() {
    var MERKLE_TREE_LEVELS = 20;
    var NUM_INPUTS = 2;
    var NUM_OUTPUTS = 2;

    signal input inputAmounts[NUM_INPUTS];
    signal input inputSecrets[NUM_INPUTS];
    signal input inputNullifiers[NUM_INPUTS];

    signal input inputPathElements[NUM_INPUTS][MERKLE_TREE_LEVELS];
    signal input inputPathIndices[NUM_INPUTS][MERKLE_TREE_LEVELS];

    signal input outputAmounts[NUM_OUTPUTS];
    signal input outputSecrets[NUM_OUTPUTS];
    signal input outputNullifiers[NUM_OUTPUTS];

    signal input merkleRoot;

    signal output inputNullifierHashes[NUM_INPUTS];
    signal output outputCommitments[NUM_OUTPUTS];

    component inputCommitmentHashers[NUM_INPUTS];
    component merkleProofs[NUM_INPUTS];

    for (var i = 0; i < NUM_INPUTS; i++) {
        inputCommitmentHashers[i] = Poseidon(3);
        inputCommitmentHashers[i].inputs[0] <== inputAmounts[i];
        inputCommitmentHashers[i].inputs[1] <== inputSecrets[i];
        inputCommitmentHashers[i].inputs[2] <== inputNullifiers[i];

        merkleProofs[i] = MerkleTreeInclusionProof(MERKLE_TREE_LEVELS);
        merkleProofs[i].leaf <== inputCommitmentHashers[i].out;
        for (var j = 0; j < MERKLE_TREE_LEVELS; j++) {
            merkleProofs[i].pathElements[j] <== inputPathElements[i][j];
            merkleProofs[i].pathIndices[j] <== inputPathIndices[i][j];
        }

        merkleProofs[i].root === merkleRoot;
    }

    component inputNullifierHashers[NUM_INPUTS];

    for (var i = 0; i < NUM_INPUTS; i++) {
        inputNullifierHashers[i] = Poseidon(1);
        inputNullifierHashers[i].inputs[0] <== inputNullifiers[i];
        inputNullifierHashes[i] <== inputNullifierHashers[i].out;
    }

    component outputCommitmentHashers[NUM_OUTPUTS];

    for (var i = 0; i < NUM_OUTPUTS; i++) {
        outputCommitmentHashers[i] = Poseidon(3);
        outputCommitmentHashers[i].inputs[0] <== outputAmounts[i];
        outputCommitmentHashers[i].inputs[1] <== outputSecrets[i];
        outputCommitmentHashers[i].inputs[2] <== outputNullifiers[i];
        outputCommitments[i] <== outputCommitmentHashers[i].out;
    }

    signal inputSum;
    signal outputSum;

    signal inputPartialSums[NUM_INPUTS];
    inputPartialSums[0] <== inputAmounts[0];
    for (var i = 1; i < NUM_INPUTS; i++) {
        inputPartialSums[i] <== inputPartialSums[i-1] + inputAmounts[i];
    }
    inputSum <== inputPartialSums[NUM_INPUTS - 1];

    signal outputPartialSums[NUM_OUTPUTS];
    outputPartialSums[0] <== outputAmounts[0];
    for (var i = 1; i < NUM_OUTPUTS; i++) {
        outputPartialSums[i] <== outputPartialSums[i-1] + outputAmounts[i];
    }
    outputSum <== outputPartialSums[NUM_OUTPUTS - 1];

    inputSum === outputSum;

    var MAX_AMOUNT = 18446744073709551615;

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

    component nullifierEquality = IsEqual();
    nullifierEquality.in[0] <== inputNullifiers[0];
    nullifierEquality.in[1] <== inputNullifiers[1];
    nullifierEquality.out === 0;

    component outputNullifierEquality = IsEqual();
    outputNullifierEquality.in[0] <== outputNullifiers[0];
    outputNullifierEquality.in[1] <== outputNullifiers[1];
    outputNullifierEquality.out === 0;
}

component main {public [merkleRoot]} = Transfer();
