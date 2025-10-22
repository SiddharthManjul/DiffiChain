'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useWallet } from '@/contexts/WalletContext';
import { ConnectWalletButton } from '@/components/ConnectWalletButton';

export default function HomePage() {
  const { isConnected } = useWallet();
  const router = useRouter();

  useEffect(() => {
    if (isConnected) {
      router.push('/dashboard');
    }
  }, [isConnected, router]);

  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900 p-4">
      {/* Background effects */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-purple-500/20 rounded-full blur-3xl animate-pulse" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-pink-500/20 rounded-full blur-3xl animate-pulse delay-1000" />
      </div>

      {/* Main content */}
      <div className="relative z-10 flex flex-col items-center gap-12 max-w-4xl">
        {/* Logo and title */}
        <div className="text-center space-y-4">
          <h1 className="text-6xl md:text-7xl font-bold bg-gradient-to-r from-purple-400 via-pink-400 to-purple-400 bg-clip-text text-transparent animate-gradient">
            DiffiChain
          </h1>
          <p className="text-xl md:text-2xl text-gray-300">
            Confidential Token Launchpad
          </p>
        </div>

        {/* Feature highlights */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 w-full">
          <div className="p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm hover:bg-white/10 transition-colors">
            <div className="text-3xl mb-3">🔒</div>
            <h3 className="text-lg font-semibold text-white mb-2">Privacy-First</h3>
            <p className="text-sm text-gray-400">
              Launch and trade tokens with complete privacy using zero-knowledge proofs
            </p>
          </div>

          <div className="p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm hover:bg-white/10 transition-colors">
            <div className="text-3xl mb-3">⚡</div>
            <h3 className="text-lg font-semibold text-white mb-2">Smart Accounts</h3>
            <p className="text-sm text-gray-400">
              ERC-4337 smart accounts with MetaMask for enhanced security and UX
            </p>
          </div>

          <div className="p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm hover:bg-white/10 transition-colors">
            <div className="text-3xl mb-3">🌊</div>
            <h3 className="text-lg font-semibold text-white mb-2">Dark Pools</h3>
            <p className="text-sm text-gray-400">
              Trade confidentially with stealth addresses and encrypted orders
            </p>
          </div>
        </div>

        {/* Connect wallet section */}
        <div className="w-full max-w-md">
          <ConnectWalletButton />
        </div>

        {/* Info section */}
        <div className="text-center space-y-2 text-sm text-gray-500 max-w-2xl">
          <p>
            DiffiChain enables you to launch confidential tokens, mint privacy-preserving equivalents of existing tokens, and trade in dark pools.
          </p>
          <p className="text-xs">
            Powered by zkSNARKs • Built on Monad Testnet • ERC-5564 Stealth Addresses
          </p>
        </div>
      </div>
    </div>
  );
}
