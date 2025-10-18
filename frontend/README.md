# DiffiChain Frontend

Next.js application for DiffiChain confidential token platform.

## Directory Structure

```
frontend/
├── src/
│   ├── app/              # Next.js App Router pages
│   ├── components/       # React components
│   ├── lib/             # Core libraries (wagmi, viem config)
│   ├── hooks/           # Custom React hooks
│   ├── types/           # TypeScript type definitions
│   ├── utils/           # Utility functions
│   └── workers/         # Web Workers for ZK proof generation
├── public/
│   └── zkproofs/        # ZK proof artifacts (wasm, zkey)
├── scripts/             # Build and setup scripts
├── package.json
├── tsconfig.json
├── next.config.js
├── tailwind.config.ts
└── README.md
```

## Features

- **Wallet Integration**: RainbowKit + wagmi for wallet connections
- **ZK Proof Generation**: Client-side proof generation using snarkjs
- **Stealth Addresses**: ERC-5564 stealth address derivation
- **MetaMask Smart Accounts**: ERC-4337 account abstraction support
- **Responsive UI**: TailwindCSS for styling

## Setup

```bash
# Install dependencies
npm install

# Copy ZK proof artifacts from circuits
npm run setup:zkproofs

# Run development server
npm run dev
```

## Development

```bash
# Start dev server (http://localhost:3000)
npm run dev

# Type checking
npm run type-check

# Linting
npm run lint

# Build for production
npm run build

# Start production server
npm start
```

## ZK Proof Generation

Proofs are generated client-side in Web Workers to avoid blocking the UI:
- Deposit proofs: ~5-10 seconds
- Transfer proofs: ~10-20 seconds
- Withdraw proofs: ~5-10 seconds

## Environment Variables

Create `.env.local`:
```
NEXT_PUBLIC_CHAIN_ID=10200
NEXT_PUBLIC_RPC_URL=https://testnet1.monad.xyz
NEXT_PUBLIC_ENABLE_TESTNETS=true
```

## Key Components

- **ProofWorker**: Generates ZK proofs in background thread
- **WalletProvider**: Wagmi + RainbowKit setup
- **StealthAddress**: Stealth address generation and scanning
- **NoteManager**: Manages user's confidential notes
