'use client';

import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';
import { createPublicClient, createWalletClient, custom, http, type Address, type Hex } from 'viem';
import { Implementation, toMetaMaskSmartAccount } from '@metamask/delegation-toolkit';
import type { WalletContextType, SmartAccountInfo } from '@/types/wallet';
import { config } from '@/lib/config';

const WalletContext = createContext<WalletContextType | null>(null);

export function WalletProvider({ children }: { children: React.ReactNode }) {
  const [eoaAddress, setEoaAddress] = useState<Address | null>(null);
  const [smartAccount, setSmartAccount] = useState<SmartAccountInfo | null>(null);
  const [isConnecting, setIsConnecting] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [publicClient, setPublicClient] = useState<any>(null);
  const [smartAccountInstance, setSmartAccountInstance] = useState<any>(null);
  const [isSmartAccountReady, setIsSmartAccountReady] = useState(false);

  // Initialize public client on mount
  useEffect(() => {
    console.log('✅ WalletProvider: Initializing public client...');

    const pubClient = createPublicClient({
      chain: config.chain,
      transport: http(),
    });

    setPublicClient(pubClient);
    console.log('✅ Public client initialized');
  }, []);

  // Storage key for smart account address
  const getSmartAccountStorageKey = useCallback((addr: string) => {
    return `diffichain_smart_account_${addr.toLowerCase()}`;
  }, []);

  // Check for existing connection on mount
  useEffect(() => {
    const checkConnection = async () => {
      if (typeof window === 'undefined' || !window.ethereum) return;

      try {
        const accounts = await window.ethereum.request({ method: 'eth_accounts' });
        if (accounts && accounts.length > 0) {
          const addr = accounts[0] as Address;
          setEoaAddress(addr);
          setIsConnected(true);

          // Check if we have a stored smart account address
          const storedSmartAccount = localStorage.getItem(getSmartAccountStorageKey(addr));
          if (storedSmartAccount) {
            setIsSmartAccountReady(true);
          }
        }
      } catch (err) {
        console.error('Error checking connection:', err);
      }
    };

    checkConnection();
  }, [getSmartAccountStorageKey]);

  /**
   * Lazy initialization of Smart Account (only when needed)
   * Based on ensureSmartAccount from useDelegation hook
   */
  const ensureSmartAccount = useCallback(async (address: Address) => {
    if (!address || !publicClient) {
      throw new Error('Wallet not connected');
    }

    // If we already have a smart account instance, return it
    if (smartAccountInstance) {
      return smartAccountInstance;
    }

    try {
      // Check if we have a stored smart account address
      const storedAddress = localStorage.getItem(getSmartAccountStorageKey(address));

      if (storedAddress) {
        // Verify the account is actually deployed on-chain
        const code = await publicClient.getBytecode({ address: storedAddress as Address });

        if (code && code !== '0x') {
          console.log('✅ Found existing Smart Account:', storedAddress);

          // Recreate the smart account instance with the same parameters
          const deterministicSalt = `0x${address.slice(2).padStart(64, '0')}` as Hex;

          // Create wallet client
          const walletClient = createWalletClient({
            account: address,
            chain: config.chain,
            transport: custom(window.ethereum),
          });

          const account = await toMetaMaskSmartAccount({
            client: publicClient,
            implementation: Implementation.Hybrid,
            deployParams: [address as Address, [], [], []],
            deploySalt: deterministicSalt,
            signer: { walletClient }
          });

          setSmartAccountInstance(account);
          setSmartAccount({
            address: account.address,
            isDeployed: true,
            implementation: 'Hybrid',
          });
          setIsSmartAccountReady(true);
          return account;
        } else {
          console.log('⚠️ Stored smart account not deployed, creating new one');
        }
      }

      // Create new smart account
      console.log('🔧 Creating new Smart Account...');
      const deterministicSalt = `0x${address.slice(2).padStart(64, '0')}` as Hex;

      // Create wallet client
      const walletClient = createWalletClient({
        account: address,
        chain: config.chain,
        transport: custom(window.ethereum),
      });

      const account = await toMetaMaskSmartAccount({
        client: publicClient,
        implementation: Implementation.Hybrid,
        deployParams: [address as Address, [], [], []],
        deploySalt: deterministicSalt,
        signer: { walletClient }
      });

      // Check if deployed
      const code = await publicClient.getBytecode({ address: account.address });
      const isDeployed = !!(code && code !== '0x');

      // Store the smart account address
      localStorage.setItem(getSmartAccountStorageKey(address), account.address);

      setSmartAccountInstance(account);
      setSmartAccount({
        address: account.address,
        isDeployed,
        implementation: 'Hybrid',
      });
      setIsSmartAccountReady(true);

      console.log('✅ Smart Account created:', account.address);
      console.log('   Deployed:', isDeployed ? 'Yes' : 'No (Counterfactual)');

      return account;
    } catch (error) {
      console.error('❌ Failed to initialize Smart Account:', error);
      setIsSmartAccountReady(false);
      throw error;
    }
  }, [publicClient, smartAccountInstance, getSmartAccountStorageKey]);

  const connect = useCallback(async () => {
    console.log('🔵 Connect function called');
    setIsConnecting(true);
    setError(null);

    try {
      // Check if MetaMask is installed
      if (typeof window === 'undefined' || !window.ethereum) {
        throw new Error('MetaMask is not installed. Please install MetaMask to continue.');
      }

      console.log('🔵 MetaMask detected, requesting accounts...');

      // Request account access
      const accounts = await window.ethereum.request({
        method: 'eth_requestAccounts',
      });

      console.log('✅ Accounts received:', accounts);

      if (!accounts || accounts.length === 0) {
        throw new Error('No accounts found');
      }

      const ownerAddress = accounts[0] as Address;
      setEoaAddress(ownerAddress);
      setIsConnected(true);

      // Store connection state
      if (typeof window !== 'undefined') {
        localStorage.setItem('wallet_connected', 'true');
      }

      // Try to initialize smart account (lazy loading)
      // Pass ownerAddress directly to avoid race condition with state
      if (publicClient) {
        try {
          await ensureSmartAccount(ownerAddress);
          console.log('✅ Smart Account integration complete!');
        } catch (smartAccErr: any) {
          console.error('❌ Smart account creation failed:', smartAccErr);
          console.error('   Error details:', smartAccErr.message);
          console.log('⚠️  Continuing with EOA mode');
        }
      }

      console.log('✅ Wallet connected successfully!');
    } catch (err: any) {
      console.error('❌ Connection error:', err);
      setError(err.message || 'Failed to connect wallet');
      setIsConnected(false);
    } finally {
      setIsConnecting(false);
    }
  }, [publicClient, ensureSmartAccount]);

  const disconnect = useCallback(() => {
    console.log('🔴 Disconnecting wallet');
    setEoaAddress(null);
    setSmartAccount(null);
    setSmartAccountInstance(null);
    setIsConnected(false);
    setIsSmartAccountReady(false);
    setError(null);

    if (typeof window !== 'undefined') {
      localStorage.removeItem('wallet_connected');
    }
  }, []);

  const sendTransaction = useCallback(
    async (params: { to: Address; value?: bigint; data?: `0x${string}` }) => {
      if (!eoaAddress) {
        throw new Error('Wallet not connected');
      }

      try {
        console.log('📤 Sending transaction:', params);

        // For now, use regular MetaMask transaction
        // Smart account transactions will be implemented when needed
        console.log('📤 Using regular MetaMask transaction');

        const txHash = await window.ethereum.request({
          method: 'eth_sendTransaction',
          params: [{
            from: eoaAddress,
            to: params.to,
            value: params.value ? `0x${params.value.toString(16)}` : '0x0',
            data: params.data || '0x',
          }],
        });

        console.log('✅ Transaction sent:', txHash);
        return txHash as `0x${string}`;
      } catch (err: any) {
        console.error('❌ Transaction error:', err);
        throw new Error(err.message || 'Failed to send transaction');
      }
    },
    [eoaAddress]
  );

  // Listen for account changes
  useEffect(() => {
    if (typeof window === 'undefined' || !window.ethereum) return;

    const handleAccountsChanged = (accounts: string[]) => {
      if (accounts.length === 0) {
        disconnect();
      } else if (accounts[0] !== eoaAddress) {
        // Account changed, reconnect
        setEoaAddress(null);
        setSmartAccount(null);
        setSmartAccountInstance(null);
        setIsConnected(false);
        setIsSmartAccountReady(false);
      }
    };

    const handleChainChanged = () => {
      // Reload the page on chain change
      window.location.reload();
    };

    window.ethereum.on('accountsChanged', handleAccountsChanged);
    window.ethereum.on('chainChanged', handleChainChanged);

    return () => {
      window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
      window.ethereum.removeListener('chainChanged', handleChainChanged);
    };
  }, [eoaAddress, disconnect]);

  const value: WalletContextType = {
    eoaAddress,
    smartAccount,
    isConnecting,
    isConnected,
    error,
    connect,
    disconnect,
    sendTransaction,
  };

  return <WalletContext.Provider value={value}>{children}</WalletContext.Provider>;
}

export function useWallet() {
  const context = useContext(WalletContext);
  if (!context) {
    throw new Error('useWallet must be used within a WalletProvider');
  }
  return context;
}

// Type declaration for window.ethereum
declare global {
  interface Window {
    ethereum?: any;
  }
}
