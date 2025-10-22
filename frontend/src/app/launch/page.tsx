'use client';

import { useState } from 'react';
import { ProtectedRoute } from '@/components/ProtectedRoute';
import { Navigation } from '@/components/Navigation';
import { useWallet } from '@/contexts/WalletContext';

export default function LaunchTokenPage() {
  const { sendTransaction } = useWallet();
  const [formData, setFormData] = useState({
    name: '',
    symbol: '',
    totalSupply: '',
    decimals: '18',
    description: '',
  });
  const [isLaunching, setIsLaunching] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const handleLaunch = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLaunching(true);
    setError(null);
    setSuccess(null);

    try {
      // Validate inputs
      if (!formData.name || !formData.symbol || !formData.totalSupply) {
        throw new Error('Please fill in all required fields');
      }

      // TODO: Implement actual token launch logic
      // This will involve:
      // 1. Deploying a new zkERC20 contract
      // 2. Setting up initial commitments
      // 3. Configuring privacy parameters

      // Placeholder for demonstration
      await new Promise((resolve) => setTimeout(resolve, 2000));

      setSuccess(
        `Token ${formData.symbol} launched successfully! Contract deployment pending...`
      );

      // Reset form
      setFormData({
        name: '',
        symbol: '',
        totalSupply: '',
        decimals: '18',
        description: '',
      });
    } catch (err: any) {
      setError(err.message || 'Failed to launch token');
    } finally {
      setIsLaunching(false);
    }
  };

  return (
    <ProtectedRoute>
      <div className="min-h-screen bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900">
        <Navigation />

        <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-4xl font-bold text-white mb-2">Launch New Token</h1>
            <p className="text-gray-400">
              Create a new confidential token with zero-knowledge privacy features
            </p>
          </div>

          {/* Launch form */}
          <div className="bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm p-8">
            <form onSubmit={handleLaunch} className="space-y-6">
              {/* Token Name */}
              <div>
                <label htmlFor="name" className="block text-sm font-medium text-gray-300 mb-2">
                  Token Name *
                </label>
                <input
                  type="text"
                  id="name"
                  name="name"
                  value={formData.name}
                  onChange={handleInputChange}
                  placeholder="e.g., Privacy Token"
                  className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                  required
                />
              </div>

              {/* Token Symbol */}
              <div>
                <label htmlFor="symbol" className="block text-sm font-medium text-gray-300 mb-2">
                  Token Symbol *
                </label>
                <input
                  type="text"
                  id="symbol"
                  name="symbol"
                  value={formData.symbol}
                  onChange={handleInputChange}
                  placeholder="e.g., PRIV"
                  className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent uppercase"
                  required
                />
              </div>

              {/* Grid for Total Supply and Decimals */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Total Supply */}
                <div>
                  <label htmlFor="totalSupply" className="block text-sm font-medium text-gray-300 mb-2">
                    Total Supply *
                  </label>
                  <input
                    type="number"
                    id="totalSupply"
                    name="totalSupply"
                    value={formData.totalSupply}
                    onChange={handleInputChange}
                    placeholder="e.g., 1000000"
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                    required
                  />
                </div>

                {/* Decimals */}
                <div>
                  <label htmlFor="decimals" className="block text-sm font-medium text-gray-300 mb-2">
                    Decimals
                  </label>
                  <input
                    type="number"
                    id="decimals"
                    name="decimals"
                    value={formData.decimals}
                    onChange={handleInputChange}
                    placeholder="18"
                    className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                  />
                </div>
              </div>

              {/* Description */}
              <div>
                <label htmlFor="description" className="block text-sm font-medium text-gray-300 mb-2">
                  Description
                </label>
                <textarea
                  id="description"
                  name="description"
                  value={formData.description}
                  onChange={handleInputChange}
                  rows={4}
                  placeholder="Describe your token and its use case..."
                  className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent resize-none"
                />
              </div>

              {/* Info box */}
              <div className="p-4 bg-blue-900/20 border border-blue-500/30 rounded-lg">
                <div className="flex items-start">
                  <svg className="w-5 h-5 text-blue-400 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <div className="text-sm text-blue-300">
                    <p className="font-medium mb-1">Privacy Features:</p>
                    <ul className="list-disc list-inside space-y-1 text-blue-400">
                      <li>All balances and transactions will be confidential</li>
                      <li>Uses note-based UTXO model with zkSNARK proofs</li>
                      <li>Supports stealth addresses for receiving tokens</li>
                      <li>Token will be deployed on your first transaction</li>
                    </ul>
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
                disabled={isLaunching}
                className="w-full px-6 py-4 text-lg font-semibold text-white bg-gradient-to-r from-purple-600 to-pink-600 rounded-xl hover:from-purple-700 hover:to-pink-700 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl"
              >
                {isLaunching ? 'Launching Token...' : 'Launch Token'}
              </button>
            </form>
          </div>

          {/* Additional info */}
          <div className="mt-8 p-6 bg-white/5 border border-white/10 rounded-xl backdrop-blur-sm">
            <h3 className="text-lg font-semibold text-white mb-4">What happens next?</h3>
            <ol className="space-y-3 text-sm text-gray-400">
              <li className="flex items-start">
                <span className="flex-shrink-0 w-6 h-6 flex items-center justify-center rounded-full bg-purple-600 text-white text-xs font-semibold mr-3">
                  1
                </span>
                <span>Your token parameters will be validated and a zkERC20 contract will be prepared</span>
              </li>
              <li className="flex items-start">
                <span className="flex-shrink-0 w-6 h-6 flex items-center justify-center rounded-full bg-purple-600 text-white text-xs font-semibold mr-3">
                  2
                </span>
                <span>Initial commitments and privacy parameters will be set up</span>
              </li>
              <li className="flex items-start">
                <span className="flex-shrink-0 w-6 h-6 flex items-center justify-center rounded-full bg-purple-600 text-white text-xs font-semibold mr-3">
                  3
                </span>
                <span>The contract will be deployed on your first transaction (counterfactual deployment)</span>
              </li>
              <li className="flex items-start">
                <span className="flex-shrink-0 w-6 h-6 flex items-center justify-center rounded-full bg-purple-600 text-white text-xs font-semibold mr-3">
                  4
                </span>
                <span>You can start minting and transferring tokens with complete privacy</span>
              </li>
            </ol>
          </div>
        </main>
      </div>
    </ProtectedRoute>
  );
}
