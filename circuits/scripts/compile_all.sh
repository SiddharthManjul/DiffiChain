#!/bin/bash

###############################################################################
# DiffiChain Circuit Compilation Script
#
# This script compiles all Circom circuits and generates the necessary
# artifacts for proof generation and verification.
#
# Usage:
#   ./scripts/compile_all.sh [circuit_name]
#
# If no circuit name is provided, all circuits will be compiled.
#
# Requirements:
#   - circom (v2.0.0+)
#   - snarkjs (latest)
#   - Node.js (v16+)
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CIRCUITS_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$CIRCUITS_DIR/src"
BUILD_DIR="$CIRCUITS_DIR/build"
KEYS_DIR="$CIRCUITS_DIR/keys"
CONTRACTS_DIR="$CIRCUITS_DIR/../contracts/src"

# Circuit names
CIRCUITS=("deposit" "transfer" "withdraw")

# Powers of Tau file (for trusted setup)
PTAU_FILE="$KEYS_DIR/powersOfTau28_hez_final_14.ptau"
PTAU_URL="https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_14.ptau"

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_dependencies() {
    print_header "Checking Dependencies"

    # Check circom
    if ! command -v circom &> /dev/null; then
        print_error "circom not found. Please install it:"
        echo "  npm install -g circom"
        exit 1
    fi
    print_success "circom: $(circom --version)"

    # Check snarkjs
    if ! command -v snarkjs &> /dev/null; then
        print_error "snarkjs not found. Please install it:"
        echo "  npm install -g snarkjs"
        exit 1
    fi
    print_success "snarkjs: installed"

    # Check node
    if ! command -v node &> /dev/null; then
        print_error "node not found. Please install Node.js v16+"
        exit 1
    fi
    print_success "node: $(node --version)"

    echo ""
}

create_directories() {
    print_info "Creating directories..."
    mkdir -p "$BUILD_DIR"
    mkdir -p "$KEYS_DIR"
    mkdir -p "$CONTRACTS_DIR"
    print_success "Directories created"
    echo ""
}

download_ptau() {
    if [ ! -f "$PTAU_FILE" ]; then
        print_header "Downloading Powers of Tau"
        print_info "This is a one-time download (~288 MB)..."
        curl -o "$PTAU_FILE" "$PTAU_URL"
        print_success "Powers of Tau downloaded"
    else
        print_info "Powers of Tau already exists, skipping download"
    fi
    echo ""
}

compile_circuit() {
    local circuit_name=$1
    local circuit_file="$SRC_DIR/${circuit_name}.circom"

    print_header "Compiling ${circuit_name}.circom"

    # Check if circuit file exists
    if [ ! -f "$circuit_file" ]; then
        print_error "Circuit file not found: $circuit_file"
        return 1
    fi

    # Compile circuit
    print_info "Generating R1CS, WASM, and symbols..."
    circom "$circuit_file" \
        --r1cs \
        --wasm \
        --sym \
        --inspect \
        -o "$BUILD_DIR"

    if [ $? -eq 0 ]; then
        print_success "Circuit compiled successfully"
    else
        print_error "Circuit compilation failed"
        return 1
    fi

    # Print circuit info
    print_info "Circuit statistics:"
    snarkjs r1cs info "$BUILD_DIR/${circuit_name}.r1cs" | grep -E "# of"

    echo ""
}

generate_zkey() {
    local circuit_name=$1
    local r1cs_file="$BUILD_DIR/${circuit_name}.r1cs"
    local zkey_0="$KEYS_DIR/${circuit_name}_0000.zkey"
    local zkey_final="$KEYS_DIR/${circuit_name}_final.zkey"

    print_header "Generating zkey for $circuit_name"

    # Check if already exists
    if [ -f "$zkey_final" ]; then
        print_warning "Final zkey already exists, skipping generation"
        echo ""
        return 0
    fi

    # Phase 2 setup
    print_info "Running Groth16 setup..."
    snarkjs groth16 setup "$r1cs_file" "$PTAU_FILE" "$zkey_0"

    # Contribute to ceremony (using random beacon for development)
    print_info "Contributing to ceremony..."
    echo "random text" | snarkjs zkey contribute "$zkey_0" "$zkey_final" \
        --name="Development contribution" -v

    # Clean up intermediate file
    rm -f "$zkey_0"

    print_success "zkey generated successfully"
    echo ""
}

export_verification_key() {
    local circuit_name=$1
    local zkey_final="$KEYS_DIR/${circuit_name}_final.zkey"
    local vkey_file="$KEYS_DIR/${circuit_name}_verification_key.json"

    print_header "Exporting verification key for $circuit_name"

    snarkjs zkey export verificationkey "$zkey_final" "$vkey_file"

    print_success "Verification key exported"
    echo ""
}

export_solidity_verifier() {
    local circuit_name=$1
    local zkey_final="$KEYS_DIR/${circuit_name}_final.zkey"

    # Capitalize first letter for contract name
    local contract_name="$(echo "$circuit_name" | sed 's/^./\U&/')Verifier"
    local verifier_file="$CONTRACTS_DIR/${contract_name}.sol"

    print_header "Generating Solidity verifier for $circuit_name"

    snarkjs zkey export solidityverifier "$zkey_final" "$verifier_file"

    # Update contract name in generated file
    sed -i.bak "s/contract Groth16Verifier/contract ${contract_name}/" "$verifier_file"
    rm -f "${verifier_file}.bak"

    print_success "Solidity verifier generated: $verifier_file"
    echo ""
}

verify_circuit() {
    local circuit_name=$1

    print_header "Verifying $circuit_name circuit"

    # Check for unconstrained signals
    print_info "Checking for unconstrained signals..."
    circom "$SRC_DIR/${circuit_name}.circom" --r1cs --wasm --sym --inspect -o "$BUILD_DIR" 2>&1 | grep -i "unconstrained" || print_success "No unconstrained signals found"

    echo ""
}

process_circuit() {
    local circuit_name=$1

    echo ""
    print_header "Processing $circuit_name"
    echo ""

    compile_circuit "$circuit_name" || return 1
    verify_circuit "$circuit_name"
    generate_zkey "$circuit_name"
    export_verification_key "$circuit_name"
    export_solidity_verifier "$circuit_name"

    print_success "✓ $circuit_name completed successfully"
    echo ""
}

###############################################################################
# Main Script
###############################################################################

main() {
    print_header "DiffiChain Circuit Compilation"
    echo ""

    check_dependencies
    create_directories
    download_ptau

    # Process specified circuit or all circuits
    if [ -n "$1" ]; then
        # Single circuit specified
        circuit_name="$1"
        print_info "Processing single circuit: $circuit_name"
        process_circuit "$circuit_name"
    else
        # Process all circuits
        print_info "Processing all circuits: ${CIRCUITS[*]}"
        echo ""

        for circuit in "${CIRCUITS[@]}"; do
            process_circuit "$circuit"
        done
    fi

    print_header "Compilation Complete"
    print_success "All circuits compiled successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. Review generated Solidity verifiers in: $CONTRACTS_DIR"
    echo "  2. Deploy verifier contracts to blockchain"
    echo "  3. Test proof generation with: npm test"
    echo "  4. Integrate with frontend application"
    echo ""
    print_warning "IMPORTANT: These keys are for DEVELOPMENT ONLY!"
    print_warning "For production, conduct a proper trusted setup ceremony."
    echo ""
}

# Run main function with all arguments
main "$@"
