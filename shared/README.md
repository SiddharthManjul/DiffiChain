# Shared Utilities

Shared TypeScript utilities, types, and constants used across DiffiChain components.

## Directory Structure

```
shared/
├── src/
│   ├── types/           # TypeScript type definitions
│   ├── utils/           # Utility functions
│   └── constants/       # Shared constants
├── dist/                # Compiled output
├── package.json
├── tsconfig.json
└── README.md
```

## Usage

Import shared utilities in other packages:

```typescript
import { Note, Commitment } from '@diffichain/shared/types';
import { hashCommitment, generateNullifier } from '@diffichain/shared/utils';
import { MERKLE_TREE_DEPTH } from '@diffichain/shared/constants';
```

## Contents

### Types
- Note structures
- Proof types
- Circuit inputs/outputs
- Contract ABIs types

### Utils
- Cryptographic utilities (Poseidon hash, etc.)
- Stealth address helpers
- Note management functions
- Merkle tree utilities

### Constants
- Contract addresses
- Circuit parameters
- Network configurations
- Default values

## Build

```bash
# Build TypeScript
npm run build

# Watch mode
npm run dev
```
