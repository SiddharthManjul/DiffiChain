/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  webpack: (config, { isServer }) => {
    // Handle WASM files for zkSNARK proof generation
    config.experiments = {
      ...config.experiments,
      asyncWebAssembly: true,
      layers: true,
    };

    // Handle .wasm files
    config.module.rules.push({
      test: /\.wasm$/,
      type: 'webassembly/async',
    });

    // Externalize snarkjs on server to avoid bundling issues
    if (isServer) {
      config.externals.push('snarkjs');
    }

    return config;
  },
  // Enable static file serving for ZK artifacts
  publicRuntimeConfig: {
    zkProofsPath: '/zkproofs',
  },
};

module.exports = nextConfig;
