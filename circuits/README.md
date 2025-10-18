# ZK Circuits

Circom circuits for zero-knowledge proofs in DiffiChain.

## Directory Structure

```
circuits/
├── src/                   # Circuit source files
│   ├── deposit.circom     # Deposit proof circuit
│   ├── transfer.circom    # Transfer proof circuit
│   └── withdraw.circom    # Withdrawal proof circuit
├── test/                  # Circuit tests
├── scripts/               # Build and setup scripts
├── build/                 # Compiled circuits
│   ├── final/            # Final zkey and wasm files
│   └── ptau/             # Powers of Tau files
├── package.json
└── README.md
```

## Circuits

### deposit.circom
Proves valid deposit without revealing amount.
- **Private Inputs**: amount, secret, nullifier
- **Public Outputs**: commitment, nullifierHash

### transfer.circom
Proves valid transfer using Merkle tree membership.
- **Private Inputs**: inputNote, outputNote, merklePath, secret
- **Public Outputs**: inputNullifier, outputCommitment, merkleRoot

### withdraw.circom
Proves ownership of notes for withdrawal.
- **Private Inputs**: amount, secret, nullifier
- **Public Outputs**: nullifierHash, recipient

## Setup

```bash
# Install dependencies
npm install

# Download Powers of Tau (one-time)
npm run setup:ptau

# Full circuit setup (compile + trusted setup)
npm run setup
```

## Build

```bash
# Build all circuits
npm run build

# Build specific circuit
npm run build:deposit
npm run build:transfer
npm run build:withdraw
```

## Testing

```bash
# Test all circuits
npm run test

# Test specific circuit
npm run test:deposit
```

## Generate Verifier Contracts

```bash
# Generate Solidity verifier contracts for all circuits
npm run generate:verifiers
# Output: ../contracts/src/verifiers/*.sol
```

## Circuit Compilation Steps

For each circuit, the build process:
1. Compiles circuit to R1CS and WASM
2. Generates witness
3. Performs Powers of Tau ceremony
4. Circuit-specific trusted setup
5. Exports verification key
6. Generates Solidity verifier

## Security Notes

- Always use `circom --inspect` to check for unconstrained signals
- Validate all range constraints
- Use Poseidon hash (ZK-friendly) instead of Keccak
- Test with invalid inputs to ensure proper constraints
