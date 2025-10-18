# Smart Contracts

Foundry-based Solidity smart contracts for DiffiChain confidential token platform.

## Directory Structure

```
contracts/
├── src/
│   ├── core/              # Core contract implementations
│   ├── interfaces/        # Contract interfaces
│   ├── libraries/         # Shared libraries
│   └── verifiers/         # Generated ZK verifier contracts
├── test/                  # Contract tests
├── script/                # Deployment scripts
├── foundry.toml          # Foundry configuration
└── README.md
```

## Core Contracts

- **CollateralManager.sol**: Handles ERC-20 deposits and collateral management
- **zkERC20.sol**: Confidential token using note-based UTXO model
- **StealthAddressRegistry.sol**: ERC-5564 stealth address implementation
- **DarkPool.sol**: Confidential trading with encrypted orders

## Setup

```bash
# Install Foundry dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Run specific test file
forge test --match-path test/zkERC20.t.sol

# Gas report
forge test --gas-report
```

## Deployment

```bash
# Local deployment (Anvil)
anvil  # Run in separate terminal
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Monad testnet deployment
forge script script/Deploy.s.sol --rpc-url $MONAD_TESTNET_RPC_URL --broadcast --verify
```

## Testing

All contracts include comprehensive test coverage:
- Unit tests for individual functions
- Integration tests for multi-contract interactions
- Fuzz tests for edge cases
- Gas optimization tests
