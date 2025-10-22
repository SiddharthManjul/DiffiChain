/**
 * Zero-Knowledge Proof Generation Utilities
 *
 * Handles client-side proof generation for deposit, transfer, and withdraw operations
 */

import { poseidon1, poseidon2, poseidon3, poseidon4 } from 'poseidon-lite';

// @ts-ignore - snarkjs types
const snarkjs = typeof window !== 'undefined' ? (window as any).snarkjs : null;

/**
 * Generate a random field element for secrets/nullifiers
 */
export function randomFieldElement(): bigint {
  const bytes = new Uint8Array(31); // 31 bytes for safety (< field size)
  crypto.getRandomValues(bytes);
  let value = 0n;
  for (let i = 0; i < bytes.length; i++) {
    value = (value << 8n) | BigInt(bytes[i]);
  }
  return value;
}

/**
 * Hash using Poseidon (ZK-friendly hash function)
 * Used for commitments and nullifiers
 */
export function poseidonHash(...inputs: bigint[]): bigint {
  if (inputs.length === 1) return poseidon1(inputs);
  if (inputs.length === 2) return poseidon2(inputs);
  if (inputs.length === 3) return poseidon3(inputs);
  if (inputs.length === 4) return poseidon4(inputs);
  throw new Error('Poseidon hash supports 1-4 inputs');
}

/**
 * Create a commitment for a note
 * commitment = poseidon(amount, secret, nullifier)
 */
export function createCommitment(amount: bigint, secret: bigint, nullifier: bigint): bigint {
  return poseidonHash(amount, secret, nullifier);
}

/**
 * Create a nullifier hash
 * nullifierHash = poseidon(nullifier)
 */
export function createNullifierHash(nullifier: bigint): bigint {
  return poseidonHash(nullifier);
}

/**
 * Convert bigint to hex string for Solidity
 */
export function toHex32(value: bigint): `0x${string}` {
  return `0x${value.toString(16).padStart(64, '0')}` as `0x${string}`;
}

/**
 * Note structure for privacy tokens
 */
export interface Note {
  amount: bigint;
  secret: bigint;
  nullifier: bigint;
  commitment: bigint;
  nullifierHash: bigint;
}

/**
 * Create a new note with random secret and nullifier
 */
export function createNote(amount: bigint): Note {
  const secret = randomFieldElement();
  const nullifier = randomFieldElement();
  const commitment = createCommitment(amount, secret, nullifier);
  const nullifierHash = createNullifierHash(nullifier);

  return {
    amount,
    secret,
    nullifier,
    commitment,
    nullifierHash,
  };
}

/**
 * Deposit proof inputs
 */
export interface DepositProofInputs {
  amount: bigint;
  secret: bigint;
  nullifier: bigint;
}

/**
 * Generate ZK proof for deposit
 * Proves: I know (amount, secret, nullifier) such that commitment = hash(amount, secret, nullifier)
 */
export async function generateDepositProof(
  inputs: DepositProofInputs
): Promise<{
  proof: { a: [bigint, bigint]; b: [[bigint, bigint], [bigint, bigint]]; c: [bigint, bigint] };
  publicSignals: string[];
}> {
  if (!snarkjs) {
    throw new Error('snarkjs not loaded');
  }

  console.log('🔐 Generating deposit proof...');
  console.log('   Amount:', inputs.amount.toString());

  // Prepare circuit inputs
  // Note: The circuit calculates commitment and nullifierHash as OUTPUTS
  // We only provide amount, secret, and nullifier as INPUTS
  const circuitInputs = {
    amount: inputs.amount.toString(),
    secret: inputs.secret.toString(),
    nullifier: inputs.nullifier.toString(),
  };

  console.log('   Circuit inputs prepared');

  // Generate proof
  // Note: Circuit outputs will be commitment and nullifierHash
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    circuitInputs,
    '/circuits/deposit.wasm',
    '/circuits/deposit_final.zkey'
  );

  console.log('✅ Deposit proof generated');
  console.log('   Public signals (commitment, nullifierHash):', publicSignals);

  return { proof, publicSignals };
}

/**
 * Format proof for Solidity contract call
 * Converts proof to format expected by verifier: (uint[2] a, uint[2][2] b, uint[2] c)
 */
export function formatProofForSolidity(proof: any): {
  a: [bigint, bigint];
  b: [[bigint, bigint], [bigint, bigint]];
  c: [bigint, bigint];
} {
  return {
    a: [BigInt(proof.pi_a[0]), BigInt(proof.pi_a[1])],
    b: [
      [BigInt(proof.pi_b[0][1]), BigInt(proof.pi_b[0][0])], // Note: reversed for Solidity
      [BigInt(proof.pi_b[1][1]), BigInt(proof.pi_b[1][0])],
    ],
    c: [BigInt(proof.pi_c[0]), BigInt(proof.pi_c[1])],
  };
}

/**
 * Encrypt note data for recipient
 * In production, this would use recipient's viewing key
 * For now, returns basic encrypted format
 */
export function encryptNote(note: Note, recipientAddress: string): string {
  // TODO: Implement proper encryption using recipient's viewing key
  // For now, return a placeholder encrypted format
  const data = {
    amount: note.amount.toString(),
    secret: note.secret.toString(),
    nullifier: note.nullifier.toString(),
    to: recipientAddress,
  };

  // In production: encrypt with recipient's public key
  // For development: just encode (NOT secure)
  return Buffer.from(JSON.stringify(data)).toString('base64');
}
