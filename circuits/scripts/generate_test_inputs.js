#!/usr/bin/env node

/**
 * Generate valid test inputs for DiffiChain circuits
 * This script creates inputs with valid Merkle proofs
 */

const crypto = require('crypto');
const buildPoseidon = require('circomlibjs').buildPoseidon;

// Generate random field element (252 bits max for BN128)
function randomFieldElement() {
    const bytes = crypto.randomBytes(31); // 248 bits
    return BigInt('0x' + bytes.toString('hex')).toString();
}

// Simple Merkle tree for testing (20 levels)
class SimpleMerkleTree {
    constructor(poseidon, levels = 20) {
        this.poseidon = poseidon;
        this.levels = levels;
        this.zeros = this.createZeros();
    }

    // Create zero values for each level
    createZeros() {
        const zeros = ['0'];
        for (let i = 1; i <= this.levels; i++) {
            const hash = this.poseidon([BigInt(zeros[i-1]), BigInt(zeros[i-1])]);
            zeros.push(this.poseidon.F.toString(hash));
        }
        return zeros;
    }

    // Hash two values
    hash(left, right) {
        const h = this.poseidon([BigInt(left), BigInt(right)]);
        return this.poseidon.F.toString(h);
    }

    // Get Merkle proof for a leaf at index
    getProof(leafIndex) {
        const pathElements = [];
        const pathIndices = [];
        let currentIndex = leafIndex;

        for (let level = 0; level < this.levels; level++) {
            const isRight = currentIndex % 2;
            pathIndices.push(isRight);

            // For testing, we'll use zeros as siblings
            pathElements.push(this.zeros[level]);

            currentIndex = Math.floor(currentIndex / 2);
        }

        return { pathElements, pathIndices };
    }

    // Compute root from leaf and proof
    computeRoot(leaf, pathElements, pathIndices) {
        let current = leaf;

        for (let i = 0; i < this.levels; i++) {
            const sibling = pathElements[i];
            if (pathIndices[i] === 0) {
                // Current is left, sibling is right
                current = this.hash(current, sibling);
            } else {
                // Current is right, sibling is left
                current = this.hash(sibling, current);
            }
        }

        return current;
    }
}

async function generateDepositInput() {
    const poseidon = await buildPoseidon();

    const amount = "1000000000000000000"; // 1 token
    const secret = randomFieldElement();
    const nullifier = randomFieldElement();

    // Compute commitment
    const commitment = poseidon([BigInt(amount), BigInt(secret), BigInt(nullifier)]);
    const commitmentStr = poseidon.F.toString(commitment);

    // Compute nullifier hash
    const nullifierHash = poseidon([BigInt(nullifier)]);
    const nullifierHashStr = poseidon.F.toString(nullifierHash);

    return {
        input: { amount, secret, nullifier },
        expectedOutputs: {
            commitment: commitmentStr,
            nullifierHash: nullifierHashStr
        }
    };
}

async function generateTransferInput() {
    const poseidon = await buildPoseidon();
    const tree = new SimpleMerkleTree(poseidon, 20);

    // Input note 1 (real note)
    const input1Amount = "1000000000000000000"; // 1 token
    const input1Secret = randomFieldElement();
    const input1Nullifier = randomFieldElement();

    // Input note 2 (dummy/zero note - not used)
    const input2Amount = "0"; // 0 tokens
    const input2Secret = randomFieldElement();
    const input2Nullifier = randomFieldElement();

    // Compute input commitments
    const commitment1 = poseidon([BigInt(input1Amount), BigInt(input1Secret), BigInt(input1Nullifier)]);
    const commitment1Str = poseidon.F.toString(commitment1);

    const commitment2 = poseidon([BigInt(input2Amount), BigInt(input2Secret), BigInt(input2Nullifier)]);
    const commitment2Str = poseidon.F.toString(commitment2);

    // Get Merkle proofs
    const proof1 = tree.getProof(0);
    const proof2 = tree.getProof(0); // Dummy note uses same tree position

    // Compute Merkle root - both should compute to same root
    const merkleRoot = tree.computeRoot(commitment1Str, proof1.pathElements, proof1.pathIndices);

    // Output notes (must sum to same amount: 1 + 0 = 1)
    const output1Amount = "600000000000000000";  // 0.6 token
    const output1Secret = randomFieldElement();
    const output1Nullifier = randomFieldElement();

    const output2Amount = "400000000000000000";  // 0.4 token (total = 1.0)
    const output2Secret = randomFieldElement();
    const output2Nullifier = randomFieldElement();

    return {
        inputAmounts: [input1Amount, input2Amount],
        inputSecrets: [input1Secret, input2Secret],
        inputNullifiers: [input1Nullifier, input2Nullifier],
        inputPathElements: [proof1.pathElements, proof2.pathElements],
        inputPathIndices: [proof1.pathIndices, proof2.pathIndices],
        outputAmounts: [output1Amount, output2Amount],
        outputSecrets: [output1Secret, output2Secret],
        outputNullifiers: [output1Nullifier, output2Nullifier],
        merkleRoot: merkleRoot
    };
}

async function generateWithdrawInput() {
    const poseidon = await buildPoseidon();
    const tree = new SimpleMerkleTree(poseidon, 20);

    const amount = "1000000000000000000"; // 1 token
    const secret = randomFieldElement();
    const nullifier = randomFieldElement();
    const recipient = "664429590428601471851729840354656564076901353141"; // Example address as field element

    // Compute commitment
    const commitment = poseidon([BigInt(amount), BigInt(secret), BigInt(nullifier)]);
    const commitmentStr = poseidon.F.toString(commitment);

    // Get Merkle proof
    const proof = tree.getProof(0);

    // Compute Merkle root
    const merkleRoot = tree.computeRoot(commitmentStr, proof.pathElements, proof.pathIndices);

    return {
        secret,
        nullifier,
        pathElements: proof.pathElements,
        pathIndices: proof.pathIndices,
        merkleRoot,
        amount,
        recipient
    };
}

// Main execution
async function main() {
    const fs = require('fs');
    const circuit = process.argv[2];

    if (!circuit) {
        console.log('Usage: node generate_test_inputs.js <deposit|transfer|withdraw>');
        process.exit(1);
    }

    let input;

    if (circuit === 'deposit') {
        const data = await generateDepositInput();
        input = data.input;
        console.log('Expected outputs:', JSON.stringify(data.expectedOutputs, null, 2));
    } else if (circuit === 'transfer') {
        input = await generateTransferInput();
    } else if (circuit === 'withdraw') {
        input = await generateWithdrawInput();
    } else {
        console.error('Unknown circuit:', circuit);
        process.exit(1);
    }

    const filename = `${circuit}_input.json`;
    fs.writeFileSync(filename, JSON.stringify(input, null, 2));
    console.log(`✓ Generated ${filename}`);
}

main().catch(console.error);
