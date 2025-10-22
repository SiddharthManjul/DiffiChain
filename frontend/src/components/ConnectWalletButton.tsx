'use client';

import { useWallet } from '@/contexts/WalletContext';

export function ConnectWalletButton() {
  const { isConnecting, isConnected, eoaAddress, smartAccount, error, connect, disconnect } = useWallet();

  const formatAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  if (isConnected && eoaAddress) {
    return (
      <div className="flex flex-col items-center gap-4">
        <div className="flex flex-col items-center gap-2 p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm min-w-[320px]">
          <div className="text-sm text-gray-400">Connected Wallet</div>
          <div className="text-lg font-mono text-white">{formatAddress(eoaAddress)}</div>

          {smartAccount ? (
            <>
              <div className="w-full h-px bg-white/10 my-2" />
              <div className="text-sm text-gray-400">Smart Account</div>
              <div className="text-lg font-mono text-white">{formatAddress(smartAccount.address)}</div>
              <div className="text-xs text-emerald-400">
                {smartAccount.implementation} • {smartAccount.isDeployed ? 'Deployed' : 'Counterfactual'}
              </div>
            </>
          ) : (
            <div className="text-xs text-yellow-400 mt-2">
              EOA Mode (Smart Account initialization pending)
            </div>
          )}
        </div>

        <button
          onClick={disconnect}
          className="px-6 py-2 text-sm font-medium text-white bg-red-600/20 border border-red-500/50 rounded-lg hover:bg-red-600/30 transition-colors"
        >
          Disconnect
        </button>
      </div>
    );
  }

  const handleClick = async () => {
    console.log('🟢 Button clicked!');
    console.log('🟢 Connect function exists:', typeof connect);
    try {
      await connect();
    } catch (error) {
      console.error('🔴 Error in handleClick:', error);
    }
  };

  return (
    <div className="flex flex-col items-center gap-4">
      <button
        onClick={handleClick}
        disabled={isConnecting}
        className="group relative px-8 py-4 text-lg font-semibold text-white bg-gradient-to-r from-purple-600 to-pink-600 rounded-xl hover:from-purple-700 hover:to-pink-700 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl hover:scale-105"
      >
        <span className="relative z-10">
          {isConnecting ? 'Connecting...' : 'Connect Wallet'}
        </span>
        <div className="absolute inset-0 bg-gradient-to-r from-purple-400 to-pink-400 opacity-0 group-hover:opacity-20 rounded-xl transition-opacity" />
      </button>

      {error && (
        <div className="px-4 py-3 text-sm text-red-400 bg-red-900/20 border border-red-500/30 rounded-lg max-w-md text-center">
          {error}
        </div>
      )}

      <div className="text-sm text-gray-400 text-center max-w-md">
        Connect your MetaMask wallet to access the platform. A smart account will be created automatically.
      </div>
    </div>
  );
}
