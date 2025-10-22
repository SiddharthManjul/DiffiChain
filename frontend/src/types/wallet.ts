import type { Address } from 'viem';

export interface SmartAccountInfo {
  address: Address;
  isDeployed: boolean;
  implementation: 'Hybrid' | 'Multisig' | '7702';
}

export interface WalletState {
  eoaAddress: Address | null;
  smartAccount: SmartAccountInfo | null;
  isConnecting: boolean;
  isConnected: boolean;
  error: string | null;
}

export interface WalletContextType extends WalletState {
  connect: () => Promise<void>;
  disconnect: () => void;
  sendTransaction: (params: {
    to: Address;
    value?: bigint;
    data?: `0x${string}`;
  }) => Promise<`0x${string}`>;
}
