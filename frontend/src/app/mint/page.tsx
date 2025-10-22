'use client';

import { useState, useEffect } from 'react';
import { ProtectedRoute } from '@/components/ProtectedRoute';
import { Navigation } from '@/components/Navigation';
import { useWallet } from '@/contexts/WalletContext';
import { createNote, generateDepositProof, formatProofForSolidity, encryptNote, toHex32 } from '@/lib/zkproof';
import { approveToken, depositToZkToken, waitForTransaction, CONTRACTS } from '@/lib/contracts';
import { createWalletClient, createPublicClient, custom, http, type Address, parseEther } from 'viem';
import { config } from '@/lib/config';

// Supported tokens for minting privacy equivalents
// TODO: Replace with actual deployed zkToken addresses
const SUPPORTED_TOKENS = [
  {
    name: 'Test Token',
    symbol: 'TEST',
    privacySymbol: 'zTEST',
    address: '0x0000000000000000000000000000000000000000' as Address,
    zkTokenAddress: '0x0000000000000000000000000000000000000000' as Address, // Replace with actual zkERC20 address
  },
];

export default function MintPrivacyTokenPage() {
  const { eoaAddress } = useWallet();
  const [selectedToken, setSelectedToken] = useState(SUPPORTED_TOKENS[0]);
  const [amount, setAmount] = useState('');
  const [isMinting, setIsMinting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [step, setStep] = useState<string>('');

  const handleMint = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsMinting(true);
    setError(null);
    setSuccess(null);
    setStep('');

    console.log('\n' + '='.repeat(80));
    console.log('🎭 STARTING PRIVACY TOKEN MINTING PROCESS');
    console.log('='.repeat(80));

    try {
      // Validate inputs
      console.log('\n📋 Step 1: Validating inputs...');
      if (!amount || parseFloat(amount) <= 0) {
        throw new Error('Please enter a valid amount');
      }
      console.log('   ✅ Amount is valid:', amount, selectedToken.symbol);

      if (!eoaAddress) {
        throw new Error('Wallet not connected');
      }
      console.log('   ✅ Wallet connected:', eoaAddress);

      if (!window.ethereum) {
        throw new Error('MetaMask not found');
      }
      console.log('   ✅ MetaMask detected');

      // Check if contracts are configured
      if (!CONTRACTS.collateralManager || CONTRACTS.collateralManager === '0x0000000000000000000000000000000000000000') {
        throw new Error('Contracts not deployed. Please deploy contracts first.');
      }
      console.log('   ✅ Contracts configured');
      console.log('      CollateralManager:', CONTRACTS.collateralManager);
      console.log('      DepositVerifier:', CONTRACTS.depositVerifier);

      // Check and switch to correct network
      console.log('\n🌐 Step 2: Checking network...');
      const chainId = await window.ethereum.request({ method: 'eth_chainId' });
      const targetChainId = `0x${config.chain.id.toString(16)}`; // 10143 = 0x279F

      console.log('   Current network:', chainId, '(', parseInt(chainId, 16), ')');
      console.log('   Required network:', targetChainId, '(', config.chain.id, '- Monad Testnet)');

      if (chainId !== targetChainId) {
        setStep('Switching to Monad testnet...');
        console.log('   ⚠️  Wrong network! Switching to Monad testnet...');

        try {
          // Try to switch to the network
          await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: targetChainId }],
          });
          console.log('   ✅ Network switched successfully');
        } catch (switchError: any) {
          // This error code indicates that the chain has not been added to MetaMask
          if (switchError.code === 4902) {
            console.log('   ℹ️  Monad testnet not found in MetaMask, adding it...');
            try {
              await window.ethereum.request({
                method: 'wallet_addEthereumChain',
                params: [
                  {
                    chainId: targetChainId,
                    chainName: config.chain.name,
                    nativeCurrency: {
                      name: config.chain.nativeCurrency.name,
                      symbol: config.chain.nativeCurrency.symbol,
                      decimals: config.chain.nativeCurrency.decimals,
                    },
                    rpcUrls: [config.chain.rpcUrls.default.http[0]],
                    blockExplorerUrls: config.chain.blockExplorers?.default?.url
                      ? [config.chain.blockExplorers.default.url]
                      : undefined,
                  },
                ],
              });
              console.log('   ✅ Monad testnet added to MetaMask');
            } catch (addError) {
              throw new Error('Failed to add Monad testnet to MetaMask. Please add it manually.');
            }
          } else {
            throw switchError;
          }
        }
      } else {
        console.log('   ✅ Already on correct network (Monad Testnet)');
      }

      // Create clients
      console.log('\n🔧 Step 3: Creating blockchain clients...');
      const publicClient = createPublicClient({
        chain: config.chain,
        transport: http(),
      });
      console.log('   ✅ Public client created (for reading blockchain)');

      const walletClient = createWalletClient({
        account: eoaAddress,
        chain: config.chain,
        transport: custom(window.ethereum),
      });
      console.log('   ✅ Wallet client created (for sending transactions)');

      // Convert amount to wei
      const amountWei = parseEther(amount);
      console.log('   ✅ Amount converted:', amount, selectedToken.symbol, '→', amountWei.toString(), 'wei');

      // Step 4: Generate ZK proof
      setStep('Generating zero-knowledge proof...');
      console.log('\n🔐 Step 4: Generating zero-knowledge proof...');
      console.log('   ⏳ This may take 10-30 seconds, please wait...');

      // Create a new note for the deposit
      const note = createNote(amountWei);

      console.log('   ✅ Note created with random secrets:');
      console.log('      Amount (wei):', note.amount.toString());
      console.log('      Secret:', note.secret.toString().substring(0, 20) + '...');
      console.log('      Nullifier:', note.nullifier.toString().substring(0, 20) + '...');

      // Generate deposit proof
      // The circuit will output commitment and nullifierHash
      const { proof, publicSignals } = await generateDepositProof({
        amount: note.amount,
        secret: note.secret,
        nullifier: note.nullifier,
      });

      const formattedProof = formatProofForSolidity(proof);

      // Extract commitment and nullifierHash from public signals
      // publicSignals[0] = commitment (from circuit output)
      // publicSignals[1] = nullifierHash (from circuit output)
      const commitmentFromProof = `0x${BigInt(publicSignals[0]).toString(16).padStart(64, '0')}` as `0x${string}`;
      const nullifierHashFromProof = `0x${BigInt(publicSignals[1]).toString(16).padStart(64, '0')}` as `0x${string}`;

      console.log('   ✅ Zero-knowledge proof generated successfully!');
      console.log('      Commitment:', commitmentFromProof);
      console.log('      Nullifier Hash:', nullifierHashFromProof);
      console.log('      ℹ️  These hide your amount and identity on-chain');

      // Step 5: Approve token spending
      setStep('Approving token spending...');
      console.log('\n💳 Step 5: Approving token spending...');
      console.log('   Token to approve:', selectedToken.address);
      console.log('   Spender (zkToken):', selectedToken.zkTokenAddress);
      console.log('   Amount:', amountWei.toString(), 'wei');
      console.log('   ⏳ Waiting for MetaMask approval...');

      const approveTx = await approveToken(
        walletClient,
        selectedToken.address,
        selectedToken.zkTokenAddress,
        amountWei
      );

      console.log('   ✅ Approval transaction sent!');
      console.log('      Transaction hash:', approveTx);
      console.log('   ⏳ Waiting for confirmation on blockchain...');

      await waitForTransaction(publicClient, approveTx);

      console.log('   ✅ Approval confirmed! zkToken can now spend your tokens');

      // Step 6: Deposit and mint privacy tokens
      setStep('Minting privacy tokens...');
      console.log('\n🎭 Step 6: Depositing tokens and minting privacy notes...');

      // Encrypt note data for recipient (yourself in this case)
      const encryptedNote = encryptNote(note, eoaAddress);
      console.log('   ✅ Note encrypted for recipient:', eoaAddress);

      console.log('   📤 Calling zkToken.deposit() with:');
      console.log('      Amount:', amountWei.toString(), 'wei');
      console.log('      Commitment:', commitmentFromProof);
      console.log('      Nullifier Hash:', nullifierHashFromProof);
      console.log('      ZK Proof: [', formattedProof.a.length, 'components ]');
      console.log('   ⏳ Waiting for MetaMask confirmation...');

      const depositTx = await depositToZkToken(walletClient, selectedToken.zkTokenAddress, {
        amount: amountWei,
        commitment: commitmentFromProof,
        nullifierHash: nullifierHashFromProof,
        encryptedNote,
        proof: formattedProof,
      });

      console.log('   ✅ Deposit transaction sent!');
      console.log('      Transaction hash:', depositTx);
      console.log('   ⏳ Waiting for confirmation on blockchain...');

      await waitForTransaction(publicClient, depositTx);

      console.log('   ✅ Transaction confirmed on blockchain!');

      console.log('\n💾 Step 7: Storing note for future withdrawals...');

      // Store note locally for future use (in production, use encrypted storage)
      const notes = JSON.parse(localStorage.getItem('diffichain_notes') || '[]');
      const newNote = {
        token: selectedToken.zkTokenAddress,
        amount: note.amount.toString(),
        secret: note.secret.toString(),
        nullifier: note.nullifier.toString(),
        commitment: commitmentFromProof,
        nullifierHash: nullifierHashFromProof,
        spent: false,
        createdAt: Date.now(),
        txHash: depositTx,
      };
      notes.push(newNote);
      localStorage.setItem('diffichain_notes', JSON.stringify(notes));

      console.log('   ✅ Note saved to localStorage');
      console.log('      Total notes stored:', notes.length);
      console.log('      ⚠️  IMPORTANT: Keep your secrets safe! You need them to withdraw');

      console.log('\n' + '='.repeat(80));
      console.log('🎉 SUCCESS! PRIVACY TOKEN MINTING COMPLETE!');
      console.log('='.repeat(80));
      console.log('\n📊 Summary:');
      console.log('   Token:', selectedToken.privacySymbol);
      console.log('   Amount:', amount, selectedToken.symbol);
      console.log('   Transaction:', depositTx);
      console.log('   Commitment (on-chain):', commitmentFromProof);
      console.log('   Your balance is now HIDDEN on the blockchain! 🔐');
      console.log('\n✅ Next steps:');
      console.log('   1. You can transfer these tokens privately to others');
      console.log('   2. Or withdraw them back to regular', selectedToken.symbol);
      console.log('   3. All your transactions will be completely private!');
      console.log('='.repeat(80) + '\n');

      setSuccess(
        `Successfully minted ${amount} ${selectedToken.privacySymbol}! Your privacy tokens are now available. Transaction: ${depositTx}`
      );

      // Reset amount
      setAmount('');
      setStep('');
    } catch (err: any) {
      console.error('\n' + '='.repeat(80));
      console.error('❌ MINTING FAILED');
      console.error('='.repeat(80));
      console.error('Error:', err);
      console.error('Message:', err.message);
      if (err.cause) {
        console.error('Cause:', err.cause);
      }
      console.error('='.repeat(80) + '\n');

      setError(err.message || 'Failed to mint privacy tokens');
      setStep('');
    } finally {
      setIsMinting(false);
    }
  };

  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900">
        <Navigation />

        <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-4xl font-bold text-white mb-2">Mint Privacy Token</h1>
            <p className="text-gray-400">
              Stake existing ERC-20 tokens to mint their confidential equivalents at 1:1 ratio
            </p>
          </div>

          {/* Mint form */}
          <div className="bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm p-8">
            <form onSubmit={handleMint} className="space-y-6">
              {/* Token selection */}
              <div>
                <label htmlFor="token" className="block text-sm font-medium text-gray-300 mb-2">
                  Select Token
                </label>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  {SUPPORTED_TOKENS.map((token) => (
                    <button
                      key={token.symbol}
                      type="button"
                      onClick={() => setSelectedToken(token)}
                      className={`p-4 rounded-xl border-2 transition-all text-left ${
                        selectedToken.symbol === token.symbol
                          ? 'border-purple-500 bg-purple-500/10'
                          : 'border-white/10 bg-white/5 hover:border-white/20'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <div className="text-lg font-semibold text-white">{token.symbol}</div>
                          <div className="text-sm text-gray-400">{token.name}</div>
                        </div>
                        <div className="text-right">
                          <div className="text-xs text-gray-500">Mints to</div>
                          <div className="text-sm font-medium text-purple-400">{token.privacySymbol}</div>
                        </div>
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              {/* Amount input */}
              <div>
                <label htmlFor="amount" className="block text-sm font-medium text-gray-300 mb-2">
                  Amount to Deposit
                </label>
                <div className="relative">
                  <input
                    type="number"
                    id="amount"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    step="0.000001"
                    min="0"
                    placeholder="0.0"
                    className="w-full px-4 py-4 pr-20 bg-white/5 border border-white/10 rounded-lg text-white text-xl placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                    required
                  />
                  <div className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 font-medium">
                    {selectedToken.symbol}
                  </div>
                </div>
                <div className="mt-2 flex items-center justify-between text-sm text-gray-400">
                  <span>Balance: 0.00 {selectedToken.symbol}</span>
                  <button
                    type="button"
                    className="text-purple-400 hover:text-purple-300 font-medium"
                    onClick={() => setAmount('0')}
                  >
                    MAX
                  </button>
                </div>
              </div>

              {/* Conversion info */}
              <div className="p-4 bg-white/5 border border-white/10 rounded-lg">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm text-gray-400">You will receive</span>
                  <span className="text-lg font-semibold text-white">
                    {amount || '0.0'} {selectedToken.privacySymbol}
                  </span>
                </div>
                <div className="text-xs text-gray-500">1:1 conversion ratio</div>
              </div>

              {/* Progress indicator */}
              {step && (
                <div className="p-4 bg-blue-900/20 border border-blue-500/30 rounded-lg">
                  <div className="flex items-center">
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-400 mr-3"></div>
                    <p className="text-sm text-blue-300">{step}</p>
                  </div>
                </div>
              )}

              {/* Info box */}
              <div className="p-4 bg-blue-900/20 border border-blue-500/30 rounded-lg">
                <div className="flex items-start">
                  <svg className="w-5 h-5 text-blue-400 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <div className="text-sm text-blue-300">
                    <p className="font-medium mb-1">How it works:</p>
                    <ol className="list-decimal list-inside space-y-1 text-blue-400">
                      <li>A zero-knowledge proof is generated client-side (your secrets never leave your browser)</li>
                      <li>Your {selectedToken.symbol} tokens are deposited to the zkERC20 contract</li>
                      <li>Privacy tokens ({selectedToken.privacySymbol}) are minted with a hidden commitment</li>
                      <li>You can withdraw your original tokens anytime by proving ownership with ZK proofs</li>
                    </ol>
                  </div>
                </div>
              </div>

              {/* Error message */}
              {error && (
                <div className="p-4 bg-red-900/20 border border-red-500/30 rounded-lg">
                  <p className="text-sm text-red-400">{error}</p>
                </div>
              )}

              {/* Success message */}
              {success && (
                <div className="p-4 bg-green-900/20 border border-green-500/30 rounded-lg">
                  <p className="text-sm text-green-400">{success}</p>
                </div>
              )}

              {/* Submit button */}
              <button
                type="submit"
                disabled={isMinting}
                className="w-full px-6 py-4 text-lg font-semibold text-white bg-gradient-to-r from-purple-600 to-pink-600 rounded-xl hover:from-purple-700 hover:to-pink-700 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl"
              >
                {isMinting ? (step || 'Minting Privacy Tokens...') : 'Mint Privacy Tokens'}
              </button>
            </form>
          </div>

          {/* Privacy features */}
          <div className="mt-8 grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm">
              <div className="text-2xl mb-3">🔒</div>
              <h4 className="text-lg font-semibold text-white mb-2">Complete Privacy</h4>
              <p className="text-sm text-gray-400">
                Your balance and transactions are completely hidden using zkSNARK proofs
              </p>
            </div>

            <div className="p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm">
              <div className="text-2xl mb-3">↔️</div>
              <h4 className="text-lg font-semibold text-white mb-2">1:1 Backed</h4>
              <p className="text-sm text-gray-400">
                Every privacy token is backed 1:1 by the original ERC-20 token in the collateral vault
              </p>
            </div>

            <div className="p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm">
              <div className="text-2xl mb-3">⚡</div>
              <h4 className="text-lg font-semibold text-white mb-2">Instant Redemption</h4>
              <p className="text-sm text-gray-400">
                Withdraw your original tokens anytime by burning the privacy tokens
              </p>
            </div>
          </div>
        </main>
      </div>
    </ProtectedRoute>
  );
}
