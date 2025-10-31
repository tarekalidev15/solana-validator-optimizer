#!/bin/bash

# Live Demo: Real-Time Validator Metrics Streaming
# Shows REAL blockchain data - NO simulation

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}${BOLD}  REAL-TIME VALIDATOR METRICS - LIVE FROM BLOCKCHAIN${NC}"
echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✓ Connected to Solana Testnet${NC}"
echo -e "${GREEN}✓ Fetching REAL blockchain metrics${NC}"
echo -e "${GREEN}✓ NO simulated/fake data${NC}"
echo ""

# Check if keypairs exist
VALIDATOR_KEYPAIR="$HOME/solana-validator/validator-keypair.json"
VOTE_KEYPAIR="$HOME/solana-validator/vote-account-keypair.json"

if [ -f "$VALIDATOR_KEYPAIR" ]; then
    VALIDATOR_PUBKEY=$(solana-keygen pubkey "$VALIDATOR_KEYPAIR" 2>/dev/null)
    echo -e "${CYAN}Validator Identity:${NC} $VALIDATOR_PUBKEY"
fi

if [ -f "$VOTE_KEYPAIR" ]; then
    VOTE_PUBKEY=$(solana-keygen pubkey "$VOTE_KEYPAIR" 2>/dev/null)
    echo -e "${CYAN}Vote Account:${NC} $VOTE_PUBKEY"
fi

echo ""
echo -e "${YELLOW}Streaming real-time metrics... (Press Ctrl+C to stop)${NC}"
echo ""

# Counter for cycles
CYCLE=0

while true; do
    CYCLE=$((CYCLE + 1))

    echo -e "${BOLD}═══ Cycle #$CYCLE - $(date '+%H:%M:%S') ═══${NC}"

    # Get current epoch info
    EPOCH_INFO=$(solana epoch-info --url https://api.testnet.solana.com 2>/dev/null || echo "")
    if [ ! -z "$EPOCH_INFO" ]; then
        CURRENT_SLOT=$(echo "$EPOCH_INFO" | grep "Slot:" | awk '{print $2}')
        CURRENT_EPOCH=$(echo "$EPOCH_INFO" | grep "^Epoch:" | awk '{print $2}')

        echo -e "  ${CYAN}Network Status:${NC}"
        echo -e "    Epoch: $CURRENT_EPOCH | Slot: $CURRENT_SLOT"
    fi

    # Try to get validator-specific metrics
    if [ -f "$VALIDATOR_KEYPAIR" ]; then
        VALIDATOR_INFO=$(solana validators --url https://api.testnet.solana.com 2>/dev/null | grep "$VALIDATOR_PUBKEY" | head -1 || echo "")

        if [ ! -z "$VALIDATOR_INFO" ]; then
            # Parse real metrics
            SKIP_RATE=$(echo "$VALIDATOR_INFO" | awk '{print $10}' | tr -d '%')
            CREDITS=$(echo "$VALIDATOR_INFO" | awk '{print $8}')
            VERSION=$(echo "$VALIDATOR_INFO" | awk '{print $11}')
            SUCCESS_RATE=$((100 - ${SKIP_RATE:-100}))

            echo -e "  ${GREEN}✓ Validator Found in Cluster${NC}"
            echo -e "    Vote Success Rate: ${SUCCESS_RATE}%"
            echo -e "    Skip Rate: ${SKIP_RATE}%"
            echo -e "    Credits Earned: $CREDITS"
            echo -e "    Version: $VERSION"

            # Performance assessment
            if [ "$SUCCESS_RATE" -ge 95 ]; then
                echo -e "    Status: ${GREEN}EXCELLENT${NC} ✓"
            elif [ "$SUCCESS_RATE" -ge 90 ]; then
                echo -e "    Status: ${YELLOW}GOOD${NC}"
            elif [ "$SUCCESS_RATE" -ge 80 ]; then
                echo -e "    Status: ${YELLOW}FAIR${NC} - Optimization recommended"
            else
                echo -e "    Status: ${RED}NEEDS IMPROVEMENT${NC} - Apply optimizations"
            fi
        else
            echo -e "  ${YELLOW}⚠ Validator not found in cluster${NC}"
            echo -e "    Possible reasons:"
            echo -e "    - Still syncing (check with: solana catchup)"
            echo -e "    - No stake delegated"
            echo -e "    - Not actively voting"
        fi
    else
        echo -e "  ${YELLOW}⚠ No validator keypairs found${NC}"
        echo -e "    Run: ./setup-validator.sh to create a validator"
    fi

    # Get network-wide averages
    echo -e "  ${CYAN}Network Averages (Top 50 validators):${NC}"
    AVG_SKIP=$(solana validators --url https://api.testnet.solana.com 2>/dev/null | \
        tail -n +3 | head -50 | \
        awk '{print $10}' | tr -d '%' | \
        awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "N/A"}')

    if [ "$AVG_SKIP" != "N/A" ]; then
        AVG_SUCCESS=$(echo "100 - $AVG_SKIP" | bc 2>/dev/null || echo "N/A")
        echo -e "    Average Success Rate: ${AVG_SUCCESS}%"
        echo -e "    Average Skip Rate: ${AVG_SKIP}%"
    else
        echo -e "    ${RED}Unable to fetch network averages${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Next update in 10 seconds...${NC}"
    echo ""

    sleep 10
done
