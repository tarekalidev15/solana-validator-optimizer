#!/bin/bash

# Demo script for Smart Contract Optimizer
# This demonstrates the smart contract analysis, optimization, and monitoring features

set -e

echo "==================================="
echo "Smart Contract Optimizer Demo"
echo "==================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if the binary exists
BINARY="./target/debug/solana-validator-optimizer"
if [ ! -f "$BINARY" ]; then
    echo -e "${YELLOW}Binary not found. Building project...${NC}"
    cargo build
    echo ""
fi

# Default to a well-known Solana program (Token Program)
# Users can override by passing their own program ID
PROGRAM_ID="${1:-TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA}"
RPC_URL="${2:-https://api.mainnet-beta.solana.com}"

echo -e "${CYAN}Configuration:${NC}"
echo "  Program ID: $PROGRAM_ID"
echo "  RPC URL: $RPC_URL"
echo ""

# Function to display a section header
section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# 1. Analyze Smart Contract
section "1. Analyzing Smart Contract Performance"
echo -e "${GREEN}Running: analyze-contract${NC}"
echo ""
$BINARY analyze-contract "$PROGRAM_ID" --rpc-url "$RPC_URL" || {
    echo -e "${RED}Analysis failed. This may be because:${NC}"
    echo "  - The program ID is invalid"
    echo "  - The RPC endpoint is not accessible"
    echo "  - The program has no transaction history"
    echo ""
    echo -e "${YELLOW}Try running with a valid program ID:${NC}"
    echo "  ./demo_smart_contract.sh <YOUR_PROGRAM_ID> <RPC_URL>"
    echo ""
    exit 1
}

echo ""
read -p "Press Enter to continue to optimization recommendations..."

# 2. Get Optimization Recommendations and Apply
section "2. Smart Contract Optimization"
echo -e "${GREEN}Running: optimize-contract${NC}"
echo ""
$BINARY optimize-contract "$PROGRAM_ID" --rpc-url "$RPC_URL"

echo ""
echo -e "${CYAN}Optimization Tips:${NC}"
echo "  • High CU usage? Optimize program logic and reduce loops"
echo "  • Large account sizes? Consider state compression"
echo "  • Many transactions? Implement transaction batching"
echo "  • Inefficient PDAs? Cache derived addresses"
echo ""

read -p "Press Enter to see how to monitor in real-time..."

# 3. Show how to monitor (but don't actually start it)
section "3. Real-Time Monitoring"
echo -e "${YELLOW}To monitor your smart contract in real-time, run:${NC}"
echo ""
echo "  $BINARY monitor-contract $PROGRAM_ID --rpc-url $RPC_URL"
echo ""
echo -e "${CYAN}This will:${NC}"
echo "  • Track compute unit usage over time"
echo "  • Monitor transaction volume"
echo "  • Display optimization score"
echo "  • Update every 30 seconds"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop monitoring when running.${NC}"
echo ""

# Summary
section "Demo Complete!"
echo -e "${GREEN}You've successfully:${NC}"
echo "  ✓ Analyzed smart contract performance metrics"
echo "  ✓ Received optimization recommendations"
echo "  ✓ Learned how to monitor contracts in real-time"
echo ""
echo -e "${CYAN}Available Commands:${NC}"
echo "  analyze-contract   - Analyze program performance"
echo "  optimize-contract  - Get optimization recommendations and apply them"
echo "  monitor-contract   - Real-time performance monitoring"
echo ""
echo -e "${YELLOW}Example Usage:${NC}"
echo "  $BINARY analyze-contract <PROGRAM_ID> --rpc-url <RPC_URL>"
echo "  $BINARY optimize-contract <PROGRAM_ID> --rpc-url <RPC_URL>"
echo "  $BINARY monitor-contract <PROGRAM_ID> --rpc-url <RPC_URL>"
echo ""
echo -e "${GREEN}For more information, see the documentation in the README.${NC}"
echo ""
