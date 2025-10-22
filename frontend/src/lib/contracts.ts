/**
 * Contract Interaction Utilities
 *
 * Handles interactions with DiffiChain smart contracts
 */

import { type Address, type PublicClient, type WalletClient } from 'viem';
import { config } from './config';
import CollateralManagerABI from '@/../../abi/CollateralManager.json';
import zkERC20ABI from '@/../../abi/zkERC20.json';
import DepositVerifierABI from '@/../../abi/DepositVerifier.json';

/**
 * Get contract addresses from environment
 */
export const CONTRACTS = {
  collateralManager: (process.env.NEXT_PUBLIC_COLLATERAL_MANAGER_ADDRESS || '') as Address,
  depositVerifier: (process.env.NEXT_PUBLIC_DEPOSIT_VERIFIER_ADDRESS || '') as Address,
  transferVerifier: (process.env.NEXT_PUBLIC_TRANSFER_VERIFIER_ADDRESS || '') as Address,
  withdrawVerifier: (process.env.NEXT_PUBLIC_WITHDRAW_VERIFIER_ADDRESS || '') as Address,
} as const;

/**
 * Check if contracts are configured
 */
export function areContractsConfigured(): boolean {
  return !!(
    CONTRACTS.collateralManager &&
    CONTRACTS.depositVerifier &&
    CONTRACTS.transferVerifier &&
    CONTRACTS.withdrawVerifier
  );
}

/**
 * Register a new zkERC20 token with the CollateralManager
 */
export async function registerZkToken(
  walletClient: WalletClient,
  zkTokenAddress: Address,
  underlyingTokenAddress: Address
): Promise<`0x${string}`> {
  if (!walletClient.account) {
    throw new Error('Wallet not connected');
  }

  console.log('📝 Registering zkToken with CollateralManager...');
  console.log('   zkToken:', zkTokenAddress);
  console.log('   Underlying:', underlyingTokenAddress);

  const hash = await walletClient.writeContract({
    address: CONTRACTS.collateralManager,
    abi: CollateralManagerABI,
    functionName: 'registerZkToken',
    args: [zkTokenAddress, underlyingTokenAddress],
    account: walletClient.account,
    chain: config.chain,
  });

  console.log('✅ Registration transaction sent:', hash);
  return hash;
}

/**
 * Approve ERC20 token spending
 */
export async function approveToken(
  walletClient: WalletClient,
  tokenAddress: Address,
  spender: Address,
  amount: bigint
): Promise<`0x${string}`> {
  if (!walletClient.account) {
    throw new Error('Wallet not connected');
  }

  console.log('✅ Approving token spending...');
  console.log('   Token:', tokenAddress);
  console.log('   Spender:', spender);
  console.log('   Amount:', amount.toString());

  // Standard ERC20 approve
  const hash = await walletClient.writeContract({
    address: tokenAddress,
    abi: [
      {
        name: 'approve',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [
          { name: 'spender', type: 'address' },
          { name: 'amount', type: 'uint256' },
        ],
        outputs: [{ name: '', type: 'bool' }],
      },
    ],
    functionName: 'approve',
    args: [spender, amount],
    account: walletClient.account,
    chain: config.chain,
  });

  console.log('✅ Approval transaction sent:', hash);
  return hash;
}

/**
 * Deposit ERC20 tokens and mint privacy tokens
 */
export async function depositToZkToken(
  walletClient: WalletClient,
  zkTokenAddress: Address,
  params: {
    amount: bigint;
    commitment: `0x${string}`;
    nullifierHash: `0x${string}`;
    encryptedNote: string;
    proof: {
      a: [bigint, bigint];
      b: [[bigint, bigint], [bigint, bigint]];
      c: [bigint, bigint];
    };
  }
): Promise<`0x${string}`> {
  if (!walletClient.account) {
    throw new Error('Wallet not connected');
  }

  console.log('💰 Depositing to zkToken...');
  console.log('   zkToken:', zkTokenAddress);
  console.log('   Amount:', params.amount.toString());
  console.log('   Commitment:', params.commitment);

  // Convert proof to uint256[2], uint256[2][2], uint256[2] format
  const proofA: [bigint, bigint] = params.proof.a;
  const proofB: [[bigint, bigint], [bigint, bigint]] = params.proof.b;
  const proofC: [bigint, bigint] = params.proof.c;

  const hash = await walletClient.writeContract({
    address: zkTokenAddress,
    abi: zkERC20ABI,
    functionName: 'deposit',
    args: [
      params.amount,
      params.commitment,
      params.nullifierHash,
      `0x${Buffer.from(params.encryptedNote).toString('hex')}` as `0x${string}`,
      proofA,
      proofB,
      proofC,
    ],
    account: walletClient.account,
    chain: config.chain,
  });

  console.log('✅ Deposit transaction sent:', hash);
  return hash;
}

/**
 * Wait for transaction confirmation
 */
export async function waitForTransaction(
  publicClient: PublicClient,
  hash: `0x${string}`
): Promise<void> {
  console.log('⏳ Waiting for transaction confirmation...');
  console.log('   Hash:', hash);

  const receipt = await publicClient.waitForTransactionReceipt({
    hash,
    confirmations: 1,
  });

  if (receipt.status === 'success') {
    console.log('✅ Transaction confirmed!');
  } else {
    throw new Error('Transaction failed');
  }
}

/**
 * Get the underlying token address for a zkToken
 */
export async function getUnderlyingToken(
  publicClient: PublicClient,
  zkTokenAddress: Address
): Promise<Address> {
  const underlyingToken = await publicClient.readContract({
    address: CONTRACTS.collateralManager,
    abi: CollateralManagerABI,
    functionName: 'getUnderlyingToken',
    args: [zkTokenAddress],
  });

  return underlyingToken as Address;
}

/**
 * Check if a zkToken is authorized
 */
export async function isZkTokenAuthorized(
  publicClient: PublicClient,
  zkTokenAddress: Address
): Promise<boolean> {
  const isAuthorized = await publicClient.readContract({
    address: CONTRACTS.collateralManager,
    abi: CollateralManagerABI,
    functionName: 'authorizedZkTokens',
    args: [zkTokenAddress],
  });

  return isAuthorized as boolean;
}
