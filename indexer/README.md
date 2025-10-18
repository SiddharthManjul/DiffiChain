# DiffiChain Indexer

Envio HyperSync event indexer for DiffiChain confidential token platform.

## Directory Structure

```
indexer/
├── src/                  # Event handlers and processing logic
├── config/              # Additional configuration files
├── abis/                # Contract ABIs
├── test/                # Indexer tests
├── config.yaml          # Envio configuration
├── package.json
└── README.md
```

## What is Indexed

The indexer tracks privacy-preserving events only:

### zkERC20 Events
- `NoteCommitted`: New confidential note created
- `NullifierSpent`: Note spent (prevents double-spending)
- No amounts or addresses indexed

### CollateralManager Events
- `Deposit`: ERC-20 collateral deposited
- `Withdraw`: Collateral withdrawn

### StealthAddressRegistry Events
- `StealthAddressPublished`: User publishes stealth meta-address
- `Announcement`: Payment announcement for recipient scanning

### DarkPool Events
- `OrderPlaced`: Encrypted order placed
- `OrderMatched`: Orders matched (encrypted details)
- `OrderCancelled`: Order cancelled

## Setup

```bash
# Install Envio CLI globally
npm install -g envio

# Install dependencies
npm install

# Generate code from config
npm run codegen
```

## Development

```bash
# Run indexer locally
npm run dev

# Test indexer
npm run test
```

## Deployment

```bash
# Deploy to Envio hosted service
npm run deploy
```

## Configuration

1. Update contract addresses in `config.yaml` after deployment
2. Place contract ABIs in `abis/` directory
3. Configure database connection in environment variables

## Privacy Notes

- Only commitments and nullifiers are indexed
- No plaintext amounts, addresses, or transaction details stored
- Indexer maintains privacy while enabling efficient note tracking
- Users can scan for their notes without revealing ownership
