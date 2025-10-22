'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useWallet } from '@/contexts/WalletContext';

export function Navigation() {
  const pathname = usePathname();
  const { eoaAddress, disconnect } = useWallet();

  const formatAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  const navItems = [
    { href: '/dashboard', label: 'Dashboard' },
    { href: '/launch', label: 'Launch Token' },
    { href: '/mint', label: 'Mint Privacy Token' },
  ];

  return (
    <nav className="sticky top-0 z-50 border-b border-white/10 bg-gray-900/80 backdrop-blur-md">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link href="/dashboard" className="flex items-center space-x-2">
            <span className="text-2xl font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
              DiffiChain
            </span>
          </Link>

          {/* Navigation links */}
          <div className="hidden md:flex items-center space-x-1">
            {navItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  pathname === item.href
                    ? 'bg-purple-600 text-white'
                    : 'text-gray-300 hover:bg-white/5 hover:text-white'
                }`}
              >
                {item.label}
              </Link>
            ))}
          </div>

          {/* Wallet info */}
          <div className="flex items-center space-x-4">
            {eoaAddress && (
              <div className="hidden sm:flex items-center px-3 py-1.5 bg-white/5 border border-white/10 rounded-lg">
                <span className="text-sm font-mono text-gray-300">
                  {formatAddress(eoaAddress)}
                </span>
              </div>
            )}
            <button
              onClick={disconnect}
              className="px-4 py-2 text-sm font-medium text-white bg-red-600/20 border border-red-500/50 rounded-lg hover:bg-red-600/30 transition-colors"
            >
              Disconnect
            </button>
          </div>
        </div>
      </div>

      {/* Mobile navigation */}
      <div className="md:hidden border-t border-white/10">
        <div className="flex justify-around py-2">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={`px-3 py-2 rounded-lg text-xs font-medium transition-colors ${
                pathname === item.href
                  ? 'bg-purple-600 text-white'
                  : 'text-gray-300 hover:bg-white/5 hover:text-white'
              }`}
            >
              {item.label}
            </Link>
          ))}
        </div>
      </div>
    </nav>
  );
}
