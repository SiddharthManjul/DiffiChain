'use client';

import Link from 'next/link';
import { ProtectedRoute } from '@/components/ProtectedRoute';
import { Navigation } from '@/components/Navigation';
import { useWallet } from '@/contexts/WalletContext';

export default function DashboardPage() {
  const { smartAccount } = useWallet();

  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900">
        <Navigation />

        <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          {/* Welcome section */}
          <div className="mb-12">
            <h1 className="text-4xl font-bold text-white mb-2">Welcome to DiffiChain</h1>
            <p className="text-gray-400">
              Your gateway to confidential token launching and privacy-preserving trading
            </p>
          </div>

          {/* Smart Account info */}
          {smartAccount && (
            <div className="mb-12 p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm">
              <h2 className="text-lg font-semibold text-white mb-4">Your Smart Account</h2>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <div className="text-sm text-gray-400 mb-1">Account Address</div>
                  <div className="text-sm font-mono text-white break-all">
                    {smartAccount.address}
                  </div>
                </div>
                <div>
                  <div className="text-sm text-gray-400 mb-1">Implementation</div>
                  <div className="text-sm text-emerald-400">{smartAccount.implementation}</div>
                </div>
                <div>
                  <div className="text-sm text-gray-400 mb-1">Status</div>
                  <div className="text-sm text-emerald-400">
                    {smartAccount.isDeployed ? 'Deployed' : 'Counterfactual (deploys on first tx)'}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Quick actions */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Launch Token Card */}
            <Link href="/launch">
              <div className="group p-8 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm hover:bg-white/10 hover:border-purple-500/50 transition-all cursor-pointer">
                <div className="text-4xl mb-4">🚀</div>
                <h3 className="text-2xl font-semibold text-white mb-3">Launch New Token</h3>
                <p className="text-gray-400 mb-6">
                  Create a new confidential token with zero-knowledge privacy features. Define tokenomics, set parameters, and launch your privacy-preserving token.
                </p>
                <div className="flex items-center text-purple-400 group-hover:text-purple-300 transition-colors">
                  <span className="text-sm font-medium">Get Started</span>
                  <svg className="w-4 h-4 ml-2 group-hover:translate-x-1 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              </div>
            </Link>

            {/* Mint Privacy Token Card */}
            <Link href="/mint">
              <div className="group p-8 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm hover:bg-white/10 hover:border-pink-500/50 transition-all cursor-pointer">
                <div className="text-4xl mb-4">🔒</div>
                <h3 className="text-2xl font-semibold text-white mb-3">Mint Privacy Token</h3>
                <p className="text-gray-400 mb-6">
                  Stake existing ERC-20 tokens to mint their confidential equivalents at a 1:1 ratio. ETH → zETH, USDC → zUSDC, and more.
                </p>
                <div className="flex items-center text-pink-400 group-hover:text-pink-300 transition-colors">
                  <span className="text-sm font-medium">Get Started</span>
                  <svg className="w-4 h-4 ml-2 group-hover:translate-x-1 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              </div>
            </Link>
          </div>

          {/* Features overview */}
          <div className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm">
              <div className="text-2xl mb-3">🔐</div>
              <h4 className="text-lg font-semibold text-white mb-2">Zero-Knowledge Proofs</h4>
              <p className="text-sm text-gray-400">
                All transactions are verified using zkSNARKs, ensuring complete privacy while maintaining security
              </p>
            </div>

            <div className="p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm">
              <div className="text-2xl mb-3">👻</div>
              <h4 className="text-lg font-semibold text-white mb-2">Stealth Addresses</h4>
              <p className="text-sm text-gray-400">
                ERC-5564 compliant stealth addresses for receiving tokens without revealing your identity
              </p>
            </div>

            <div className="p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm">
              <div className="text-2xl mb-3">⚙️</div>
              <h4 className="text-lg font-semibold text-white mb-2">Smart Accounts</h4>
              <p className="text-sm text-gray-400">
                ERC-4337 account abstraction for gasless transactions and enhanced user experience
              </p>
            </div>
          </div>
        </main>
      </div>
    </ProtectedRoute>
  );
}
