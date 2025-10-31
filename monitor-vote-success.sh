#!/bin/bash

# Monitor Vote Success Rate and Compare with Other Validators

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

VALIDATOR_DIR="$HOME/solana-validator"
VALIDATOR_PUBKEY="9F3XHUUV7nsKrTkZQVM1LmZ4tpsTn2Km6THFt3C7izQq"

clear
echo "================================================"
echo "   Vote Success Rate Monitor"
echo "================================================"
echo ""

while true; do
    echo -e "${BOLD}Timestamp:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Get your validator's metrics
    echo -e "${BLUE}Your Validator:${NC}"
    YOUR_INFO=$(solana validators --url https://api.testnet.solana.com 2>/dev/null | grep "$VALIDATOR_PUBKEY" || echo "Not found in cluster yet")
    
    if [ "$YOUR_INFO" != "Not found in cluster yet" ]; then
        SKIP_RATE=$(echo "$YOUR_INFO" | awk '{print $10}')
        CREDITS=$(echo "$YOUR_INFO" | awk '{print $8}')
        SUCCESS_RATE=$((100 - ${SKIP_RATE%\%}))
        
        echo "  Identity: $VALIDATOR_PUBKEY"
        echo -e "  ${GREEN}Success Rate: ${SUCCESS_RATE}%${NC}"
        echo "  Skip Rate: $SKIP_RATE"
        echo "  Credits: $CREDITS"
    else
        echo -e "  ${YELLOW}Status: Still syncing or not voting yet${NC}"
        echo "  Make sure to fund with testnet SOL"
    fi
    
    echo ""
    echo -e "${BLUE}Top Performers (for comparison):${NC}"
    # Get top 5 validators by success rate
    solana validators --url https://api.testnet.solana.com 2>/dev/null | \
        head -20 | tail -15 | \
        awk '{print $10 " " $1}' | \
        sort -n | \
        head -5 | \
        while read skip_rate identity; do
            success=$((100 - ${skip_rate%\%}))
            echo "  Success: ${success}% | Skip: $skip_rate | ID: ${identity:0:8}..."
        done
    
    echo ""
    echo -e "${CYAN}Average Network Performance:${NC}"
    AVG_SKIP=$(solana validators --url https://api.testnet.solana.com 2>/dev/null | \
        tail -n +3 | head -50 | \
        awk '{print $10}' | tr -d '%' | \
        awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
    AVG_SUCCESS=$(echo "100 - $AVG_SKIP" | bc)
    echo "  Network Avg Success Rate: ${AVG_SUCCESS}%"
    
    if [ "$YOUR_INFO" != "Not found in cluster yet" ]; then
        DIFF=$(echo "$SUCCESS_RATE - $AVG_SUCCESS" | bc)
        if (( $(echo "$DIFF > 0" | bc -l) )); then
            echo -e "  ${GREEN}You're ${DIFF}% above average!${NC}"
        else
            echo -e "  ${YELLOW}You're ${DIFF#-}% below average${NC}"
        fi
    fi
    
    echo ""
    echo "================================================"
    echo "Refreshing in 30 seconds... (Ctrl+C to exit)"
    sleep 30
    clear
done
