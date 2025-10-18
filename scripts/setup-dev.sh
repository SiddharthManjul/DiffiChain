#!/bin/bash
# Setup development environment for DiffiChain

set -e

echo "🔧 Setting up DiffiChain development environment..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js >= 18.0.0"
    exit 1
fi
echo "✅ Node.js $(node --version)"

# Check Foundry
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not found. Please install from https://book.getfoundry.sh"
    exit 1
fi
echo "✅ Foundry $(forge --version | head -n 1)"

# Check Circom
if ! command -v circom &> /dev/null; then
    echo "⚠️  Circom not found. Please install from https://docs.circom.io"
    echo "   Continuing without Circom..."
else
    echo "✅ Circom $(circom --version)"
fi

# Check snarkjs
if ! command -v snarkjs &> /dev/null; then
    echo "⚠️  snarkjs not found. Installing globally..."
    npm install -g snarkjs
fi
echo "✅ snarkjs installed"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
npm install

# Setup contracts
echo -e "${YELLOW}Setting up contracts...${NC}"
cd contracts
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0 --no-commit
cd ..

# Setup circuits
echo -e "${YELLOW}Setting up circuits...${NC}"
cd circuits
npm install
cd ..

# Setup frontend
echo -e "${YELLOW}Setting up frontend...${NC}"
cd frontend
npm install
cd ..

# Setup indexer
echo -e "${YELLOW}Setting up indexer...${NC}"
cd indexer
npm install
cd ..

# Setup shared
echo -e "${YELLOW}Setting up shared...${NC}"
cd shared
npm install
cd ..

# Create .env if not exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cp .env.example .env
    echo "⚠️  Please update .env with your values"
fi

echo ""
echo -e "${GREEN}✅ Development environment setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Update .env with your configuration"
echo "2. Build circuits: cd circuits && npm run build"
echo "3. Test contracts: cd contracts && forge test"
echo "4. Start frontend: cd frontend && npm run dev"
