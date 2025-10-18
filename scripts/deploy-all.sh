#!/bin/bash
# Deploy all DiffiChain components

set -e

echo "🚀 Starting DiffiChain deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Build circuits
echo -e "${YELLOW}Step 1: Building ZK circuits...${NC}"
cd circuits
npm install
npm run build
npm run generate:verifiers
cd ..

# Step 2: Build and test contracts
echo -e "${YELLOW}Step 2: Building and testing smart contracts...${NC}"
cd contracts
forge install
forge build
forge test
cd ..

# Step 3: Deploy contracts
echo -e "${YELLOW}Step 3: Deploying smart contracts...${NC}"
if [ "$1" == "testnet" ]; then
    echo "Deploying to Monad testnet..."
    cd contracts
    forge script script/Deploy.s.sol --rpc-url $MONAD_TESTNET_RPC_URL --broadcast --verify
    cd ..
elif [ "$1" == "local" ]; then
    echo "Deploying to local Anvil..."
    cd contracts
    forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
    cd ..
else
    echo -e "${RED}Error: Please specify 'local' or 'testnet'${NC}"
    exit 1
fi

# Step 4: Setup frontend
echo -e "${YELLOW}Step 4: Setting up frontend...${NC}"
cd frontend
npm install
npm run setup:zkproofs
npm run build
cd ..

# Step 5: Setup indexer
echo -e "${YELLOW}Step 5: Setting up indexer...${NC}"
cd indexer
npm install
npm run codegen
cd ..

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Update contract addresses in .env"
echo "2. Update indexer config.yaml with contract addresses"
echo "3. Start frontend: cd frontend && npm run dev"
echo "4. Start indexer: cd indexer && npm run dev"
