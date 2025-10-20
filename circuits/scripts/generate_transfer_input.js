#!/usr/bin/env node

/**
 * Generate valid transfer circuit input with proper Merkle tree
 * This creates a real Merkle tree with both input notes inserted
 */

const crypto = require('crypto');
const buildPoseidon = require('circomlibjs').buildPoseidon;

// Generate random field element (252 bits max for BN128)
function randomFieldElement() {
    const bytes = crypto.randomBytes(31); // 248 bits
    return BigInt('0x' + bytes.toString('hex')).toString();
}

class MerkleTree {
    constructor(poseidon, levels = 20) {
        this.poseidon = poseidon;
        this.levels = levels;
        this.zeros = this.createZeros();
        this.leaves = {};
        this.leafCount = 0;
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

    // Insert a leaf and return its index
    insert(leaf) {
        const index = this.leafCount;
        this.leaves[index] = leaf;
        this.leafCount++;
        return index;
    }

    // Get sibling at a specific level for a given index
    getSibling(index, level) {
        const levelStartIndex = index >> level;
        const isRight = levelStartIndex & 1;
        const siblingIndex = isRight ? levelStartIndex - 1 : levelStartIndex + 1;

        // Get the actual leaf/node at sibling position
        const actualSiblingIndex = siblingIndex << level;

        // If sibling exists in leaves, compute its hash up to this level
        if (level === 0 && this.leaves[actualSiblingIndex]) {
            return this.leaves[actualSiblingIndex];
        }

        // Otherwise return zero for this level
        return this.zeros[level];
    }

    // Get Merkle proof for a leaf at index
    getProof(index) {
        if (this.leaves[index] === undefined) {
            throw new Error(`Leaf at index ${index} does not exist`);
        }

        const pathElements = [];
        const pathIndices = [];

        for (let level = 0; level < this.levels; level++) {
            const levelIndex = index >> level;
            const isRight = levelIndex & 1;
            pathIndices.push(isRight);

            // Get sibling
            const sibling = this.getSibling(index, level);
            pathElements.push(sibling);
        }

        return { pathElements, pathIndices };
    }

    // Compute root
    getRoot() {
        if (this.leafCount === 0) {
            return this.zeros[this.levels];
        }

        // Build tree bottom-up
        let currentLevel = {};

        // Level 0: leaves
        for (let i = 0; i < Math.pow(2, this.levels); i++) {
            currentLevel[i] = this.leaves[i] || this.zeros[0];
        }

        // Build up the tree
        for (let level = 0; level < this.levels; level++) {
            const nextLevel = {};
            const numNodes = Math.pow(2, this.levels - level - 1);

            for (let i = 0; i < numNodes; i++) {
                const left = currentLevel[i * 2] || this.zeros[level];
                const right = currentLevel[i * 2 + 1] || this.zeros[level];
                nextLevel[i] = this.hash(left, right);
            }

            currentLevel = nextLevel;
        }

        return currentLevel[0];
    }

    // Verify a proof
    verifyProof(leaf, pathElements, pathIndices, root) {
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

        return current === root;
    }
}

async function generateTransferInput() {
    const poseidon = await buildPoseidon();
    const tree = new MerkleTree(poseidon, 20);

    console.log('Generating transfer input with proper Merkle tree...\n');

    // ============================================
    // Step 1: Create Input Notes
    // ============================================

    // Input note 1
    const input1Amount = "1000000000000000000"; // 1 token
    const input1Secret = randomFieldElement();
    const input1Nullifier = randomFieldElement();

    // Input note 2 (can be zero amount for simple test)
    const input2Amount = "0"; // 0 tokens (dummy note)
    const input2Secret = randomFieldElement();
    const input2Nullifier = randomFieldElement();

    console.log('Input Note 1:');
    console.log('  Amount:', input1Amount, '(1 token)');
    console.log('  Secret:', input1Secret.substring(0, 20) + '...');
    console.log('  Nullifier:', input1Nullifier.substring(0, 20) + '...\n');

    console.log('Input Note 2:');
    console.log('  Amount:', input2Amount, '(dummy/zero note)');
    console.log('  Secret:', input2Secret.substring(0, 20) + '...');
    console.log('  Nullifier:', input2Nullifier.substring(0, 20) + '...\n');

    // ============================================
    // Step 2: Compute Commitments
    // ============================================

    const commitment1 = poseidon([BigInt(input1Amount), BigInt(input1Secret), BigInt(input1Nullifier)]);
    const commitment1Str = poseidon.F.toString(commitment1);

    const commitment2 = poseidon([BigInt(input2Amount), BigInt(input2Secret), BigInt(input2Nullifier)]);
    const commitment2Str = poseidon.F.toString(commitment2);

    console.log('Commitments:');
    console.log('  Note 1:', commitment1Str.substring(0, 20) + '...');
    console.log('  Note 2:', commitment2Str.substring(0, 20) + '...\n');

    // ============================================
    // Step 3: Insert Notes into Merkle Tree
    // ============================================

    const index1 = tree.insert(commitment1Str);
    const index2 = tree.insert(commitment2Str);

    console.log('Inserted into Merkle tree:');
    console.log('  Note 1 at index:', index1);
    console.log('  Note 2 at index:', index2, '\n');

    // ============================================
    // Step 4: Get Merkle Root
    // ============================================

    const merkleRoot = tree.getRoot();
    console.log('Merkle Root:', merkleRoot.substring(0, 20) + '...\n');

    // ============================================
    // Step 5: Get Merkle Proofs
    // ============================================

    const proof1 = tree.getProof(index1);
    const proof2 = tree.getProof(index2);

    console.log('Generated Merkle proofs for both notes\n');

    // Verify proofs (sanity check)
    const verified1 = tree.verifyProof(commitment1Str, proof1.pathElements, proof1.pathIndices, merkleRoot);
    const verified2 = tree.verifyProof(commitment2Str, proof2.pathElements, proof2.pathIndices, merkleRoot);

    console.log('Proof Verification:');
    console.log('  Note 1:', verified1 ? '✓ Valid' : '✗ Invalid');
    console.log('  Note 2:', verified2 ? '✓ Valid' : '✗ Invalid\n');

    if (!verified1 || !verified2) {
        throw new Error('Merkle proof verification failed!');
    }

    // ============================================
    // Step 6: Create Output Notes
    // ============================================

    // Outputs must sum to same as inputs: 1 + 0 = 1
    const output1Amount = "600000000000000000";  // 0.6 token
    const output1Secret = randomFieldElement();
    const output1Nullifier = randomFieldElement();

    const output2Amount = "400000000000000000";  // 0.4 token
    const output2Secret = randomFieldElement();
    const output2Nullifier = randomFieldElement();

    console.log('Output Note 1:');
    console.log('  Amount:', output1Amount, '(0.6 token)');
    console.log('Output Note 2:');
    console.log('  Amount:', output2Amount, '(0.4 token)');
    console.log('  Total:', '1.0 token ✓\n');

    // ============================================
    // Step 7: Return Complete Input
    // ============================================

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

// Main execution
async function main() {
    const fs = require('fs');

    try {
        const input = await generateTransferInput();

        const filename = 'transfer_input.json';
        fs.writeFileSync(filename, JSON.stringify(input, null, 2));

        console.log('✅ Generated', filename);
        console.log('\nNext step:');
        console.log('  node transfer_js/generate_witness.js transfer_js/transfer.wasm transfer_input.json transfer_witness.wtns');
    } catch (error) {
        console.error('❌ Error:', error.message);
        process.exit(1);
    }
}

main().catch(console.error);
