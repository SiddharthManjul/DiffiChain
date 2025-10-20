pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";

template Deposit() {
    var MAX_AMOUNT = 18446744073709551615;

    signal input amount;
    signal input secret;
    signal input nullifier;

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

    component nullifierHasher = Poseidon(1);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHash <== nullifierHasher.out;

}

component main = Deposit();
