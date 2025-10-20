#!/bin/bash

###############################################################################
# Witness Generation Script for DiffiChain Circuits
#
# Usage:
#   ./scripts/generate_witness.sh <circuit_name> <input_file> [output_file]
#
# Example:
#   ./scripts/generate_witness.sh deposit input.json witness.wtns
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Missing arguments${NC}"
    echo "Usage: $0 <circuit_name> <input_file> [output_file]"
    echo ""
    echo "Examples:"
    echo "  $0 deposit input.json witness.wtns"
    echo "  $0 transfer transfer_input.json transfer_witness.wtns"
    echo "  $0 withdraw withdraw_input.json withdraw_witness.wtns"
    exit 1
fi

CIRCUIT_NAME=$1
INPUT_FILE=$2
OUTPUT_FILE=${3:-witness.wtns}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CIRCUITS_DIR="$(dirname "$SCRIPT_DIR")"
WASM_FILE="$CIRCUITS_DIR/build/${CIRCUIT_NAME}_js/${CIRCUIT_NAME}.wasm"
GENERATOR_JS="$CIRCUITS_DIR/build/${CIRCUIT_NAME}_js/generate_witness.js"

# Check if circuit is compiled
if [ ! -f "$WASM_FILE" ]; then
    echo -e "${RED}Error: Circuit not compiled. WASM file not found: $WASM_FILE${NC}"
    echo "Run: circom src/${CIRCUIT_NAME}.circom --r1cs --wasm --sym -o build/"
    exit 1
fi

if [ ! -f "$GENERATOR_JS" ]; then
    echo -e "${RED}Error: Witness generator not found: $GENERATOR_JS${NC}"
    exit 1
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}Error: Input file not found: $INPUT_FILE${NC}"
    exit 1
fi

# Generate witness
echo -e "${BLUE}Generating witness for ${CIRCUIT_NAME} circuit...${NC}"
echo "Input: $INPUT_FILE"
echo "Output: $OUTPUT_FILE"

cd "$CIRCUITS_DIR"
node "$GENERATOR_JS" "$WASM_FILE" "$INPUT_FILE" "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
    echo -e "${GREEN}✓ Witness generated successfully: $OUTPUT_FILE ($SIZE)${NC}"
else
    echo -e "${RED}✗ Failed to generate witness${NC}"
    exit 1
fi
