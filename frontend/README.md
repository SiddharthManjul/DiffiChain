# DiffiChain Frontend

A Next.js-based frontend for the DiffiChain confidential token launchpad, featuring MetaMask Smart Accounts (ERC-4337) integration and zero-knowledge proof privacy.

## Features

- **MetaMask Smart Accounts**: ERC-4337 account abstraction with hybrid implementation
- **Wallet Integration**: Connect with MetaMask to create smart accounts automatically
- **Token Launch**: Create new confidential tokens with privacy features
- **Privacy Minting**: Stake ERC-20 tokens to mint confidential equivalents at 1:1 ratio
- **Protected Routes**: Access control ensuring only connected users can access platform features

## Tech Stack

- **Next.js 14**: React framework with App Router
- **TypeScript**: Type-safe development
- **Tailwind CSS**: Utility-first styling
- **Viem**: TypeScript Ethereum library
- **MetaMask Delegation Toolkit**: Smart account management
- **Zustand**: State management (if needed)
- **snarkjs**: ZK proof generation (client-side)

## Getting Started

### Prerequisites

- Node.js v18 or later
- MetaMask browser extension
- Access to Monad testnet

### Installation

1. Install dependencies:
```bash
npm install
```

2. Copy environment variables:
```bash
cp .env.example .env.local
```

3. Update `.env.local` with your configuration:
   - Contract addresses (after deployment)
   - Bundler URL (if using custom bundler)
   - Chain configuration

### Development

Run the development server:

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Building for Production

```bash
npm run build
npm start
```

## Project Structure

```
frontend/
├── src/
│   ├── app/                    # Next.js App Router pages
│   │   ├── page.tsx           # Landing page with wallet connection
│   │   ├── dashboard/         # Dashboard (protected)
│   │   ├── launch/            # Token launch page (protected)
│   │   └── mint/              # Privacy token minting (protected)
│   ├── components/            # Reusable React components
│   │   ├── ConnectWalletButton.tsx
│   │   ├── Navigation.tsx
│   │   └── ProtectedRoute.tsx
│   ├── contexts/              # React contexts
│   │   └── WalletContext.tsx  # Wallet state management
│   ├── lib/                   # Utilities and configurations
│   │   └── config.ts          # App configuration
│   ├── types/                 # TypeScript type definitions
│   │   └── wallet.ts
│   └── hooks/                 # Custom React hooks
├── public/                    # Static assets
└── abi/                       # Contract ABIs (copied from ../abi)
```

## Wallet Integration

The app uses MetaMask Delegation Toolkit for smart account management:

1. **Connection Flow**:
   - User clicks "Connect Wallet"
   - MetaMask extension opens
   - User approves connection
   - Smart account is created (counterfactual)
   - Smart account deploys on first transaction

2. **Smart Account Features**:
   - Hybrid implementation (EOA + passkeys)
   - ERC-4337 compliant
   - Gasless transactions (with paymaster)
   - Batched operations support

## Pages

### Landing Page (`/`)
- Connect wallet functionality
- Feature highlights
- Redirects to dashboard when connected

### Dashboard (`/dashboard`)
- Protected route (requires wallet connection)
- Smart account information
- Quick actions to launch tokens or mint privacy tokens
- Feature overview

### Launch Token (`/launch`)
- Form to create new confidential tokens
- Token parameters: name, symbol, supply, decimals
- Privacy features explanation

### Mint Privacy Token (`/mint`)
- Select from supported ERC-20 tokens
- Enter amount to deposit
- Mint confidential equivalents at 1:1 ratio
- Balance display and transaction status

## Smart Account Implementation

The wallet context (`WalletContext.tsx`) manages:

- EOA (Externally Owned Account) connection
- Smart account creation and deployment
- Transaction signing and sending
- Account state persistence
- Error handling

## Environment Variables

Required variables in `.env.local`:

```env
NEXT_PUBLIC_CHAIN_ID=41454
NEXT_PUBLIC_RPC_URL=https://testnet1.monad.xyz
NEXT_PUBLIC_BUNDLER_URL=https://bundler.biconomy.io/api/v2/41454
NEXT_PUBLIC_COLLATERAL_MANAGER_ADDRESS=0x...
NEXT_PUBLIC_STEALTH_ADDRESS_REGISTRY_ADDRESS=0x...
# ... other contract addresses
```

## Next Steps

1. **ZK Proof Integration**: Implement client-side proof generation with snarkjs
2. **Stealth Addresses**: Add ERC-5564 stealth address generation and scanning
3. **Transaction Monitoring**: Add transaction status tracking and notifications
4. **Wallet Balance**: Display token balances and transaction history
5. **Dark Pool Trading**: Add confidential trading interface

## Troubleshooting

### MetaMask Not Detected
- Ensure MetaMask extension is installed
- Refresh the page
- Check browser console for errors

### Connection Issues
- Verify you're on the correct network (Monad testnet)
- Check RPC URL is accessible
- Ensure bundler URL is correct

### Smart Account Not Deploying
- Smart accounts deploy on first transaction
- Ensure you have sufficient gas
- Check bundler service is online

## License

MIT
