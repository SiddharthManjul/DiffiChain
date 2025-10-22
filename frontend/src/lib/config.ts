import { defineChain } from 'viem';

// Define Monad testnet chain
export const monadTestnet = defineChain({
  id: 10143,
  name: 'Monad Testnet',
  nativeCurrency: {
    decimals: 18,
    name: 'Monad',
    symbol: 'MON',
  },
  rpcUrls: {
    default: {
      http: [process.env.NEXT_PUBLIC_RPC_URL || 'https://rpc-testnet.monadinfra.com'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Monad Explorer',
      url: 'https://explorer.testnet1.monad.xyz',
    },
  },
  testnet: true,
});

// DiffiChain configuration
export const config = {
  // Chain configuration
  chain: monadTestnet,

  // Bundler configuration for ERC-4337
  bundler: {
    url: process.env.NEXT_PUBLIC_BUNDLER_URL || 'https://bundler.biconomy.io/api/v2/10143',
  },

  // Contract addresses (to be updated after deployment)
  contracts: {
    collateralManager: process.env.NEXT_PUBLIC_COLLATERAL_MANAGER_ADDRESS || '',
    zkERC20Factory: process.env.NEXT_PUBLIC_ZK_ERC20_FACTORY_ADDRESS || '',
    stealthAddressRegistry: process.env.NEXT_PUBLIC_STEALTH_ADDRESS_REGISTRY_ADDRESS || '',
    depositVerifier: process.env.NEXT_PUBLIC_DEPOSIT_VERIFIER_ADDRESS || '',
    transferVerifier: process.env.NEXT_PUBLIC_TRANSFER_VERIFIER_ADDRESS || '',
    withdrawVerifier: process.env.NEXT_PUBLIC_WITHDRAW_VERIFIER_ADDRESS || '',
  },
} as const;
