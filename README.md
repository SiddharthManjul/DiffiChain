# DiffiChain

A confidential token launchpad platform built with zero-knowledge proofs, enabling privacy-preserving token launches, transfers, and trading on Monad.

## Features

- **Confidential Tokens**: Launch zkERC20 tokens with private balances and transfers
- **Collateralized Minting**: Stake ERC-20 tokens to mint confidential equivalents at 1:1 ratio (e.g., ETH → zETH)
- **Stealth Addresses**: Privacy-preserving transfers using ERC-5564 standard
- **Dark Pool**: Confidential trading with encrypted orders
- **Zero-Knowledge Proofs**: All operations validated with ZK-SNARKs using Groth16

## Architecture

This is a monorepo containing:

- **contracts/**: Solidity smart contracts (Foundry)
- **circuits/**: Circom ZK circuits for privacy proofs
- **frontend/**: Next.js web application
- **indexer/**: Envio HyperSync event indexer
- **shared/**: Shared utilities and types

## Quick Start

### Prerequisites

- Node.js >= 18.0.0
- Foundry (https://book.getfoundry.sh/getting-started/installation)
- Circom 2.x (https://docs.circom.io/getting-started/installation/)
- SnarkJS (npm install -g snarkjs)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/diffichain.git
cd diffichain

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env
# Edit .env with your values

# Build all components
npm run build
```

### Development

```bash
# Run smart contract tests
npm run test:contracts

# Run circuit tests
npm run test:circuits

# Start frontend development server
npm run dev:frontend

# Start indexer
npm run dev:indexer
```

## Documentation

- See [CLAUDE.md](./CLAUDE.md) for detailed development guide
- Smart Contracts: [contracts/README.md](./contracts/README.md)
- ZK Circuits: [circuits/README.md](./circuits/README.md)
- Frontend: [frontend/README.md](./frontend/README.md)
- Indexer: [indexer/README.md](./indexer/README.md)

## Security

This project handles cryptographic operations and private data. Key security considerations:

- Never log or expose private inputs (secrets, nullifiers, private keys)
- Always use cryptographically secure randomness
- All ZK proofs are verified on-chain
- Stealth addresses prevent address linkability
- Note-based UTXO model prevents balance tracking

**This is experimental software. Use at your own risk.**

## License

MIT
