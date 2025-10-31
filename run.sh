#!/bin/bash

# Solana Validator Optimizer - Master Run Script
# Single command to setup, run, and optimize a testnet validator

set -e

echo "================================================"
echo "   Solana Testnet Validator Optimizer v1.0"
echo "   Maximizing Vote Success Rate Demo"
echo "================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if this is first run
VALIDATOR_DIR="$HOME/solana-validator"
FIRST_RUN=true
if [ -f "$VALIDATOR_DIR/validator-keypair.json" ]; then
    FIRST_RUN=false
fi

show_menu() {
    echo "Select an option:"
    echo ""
    if [ "$FIRST_RUN" = true ]; then
        echo "1) Initial Setup & Start Validator"
        echo "2) Exit"
    else
        echo "1) Start/Restart Validator"
        echo "2) Live Performance Dashboard (New!)"
        echo "3) Monitor Performance (Classic)"
        echo "4) Run Auto-Optimizer"
        echo "5) Generate Performance Report"
        echo "6) Stop Validator"
        echo "7) Quick Status Check"
        echo "8) Exit"
    fi
    echo ""
}

run_initial_setup() {
    echo -e "${GREEN}Running initial validator setup...${NC}"
    ./setup-validator.sh
    
    echo -e "\n${GREEN}Setup complete! Validator is starting...${NC}"
    sleep 5
    
    echo -e "\n${YELLOW}Waiting for validator to initialize (30 seconds)...${NC}"
    sleep 30
    
    echo -e "\n${GREEN}Checking initial performance...${NC}"
    ./monitor-votes.sh || true
    
    echo -e "\n${BLUE}Setup successful! You can now monitor and optimize your validator.${NC}"
}

run_status_dashboard() {
    clear
    echo "================================================"
    echo "        Validator Status Dashboard"
    echo "================================================"
    
    # Check if validator is running
    if pgrep -f solana-validator > /dev/null; then
        echo -e "${GREEN}✓ Validator Status: RUNNING${NC}"
        
        # Get validator identity
        if [ -f "$VALIDATOR_DIR/validator-keypair.json" ]; then
            VALIDATOR_PUBKEY=$(solana-keygen pubkey "$VALIDATOR_DIR/validator-keypair.json" 2>/dev/null)
            echo -e "Validator Identity: $VALIDATOR_PUBKEY"
        fi
        
        # Get vote account
        if [ -f "$VALIDATOR_DIR/vote-account-keypair.json" ]; then
            VOTE_PUBKEY=$(solana-keygen pubkey "$VALIDATOR_DIR/vote-account-keypair.json" 2>/dev/null)
            echo -e "Vote Account: $VOTE_PUBKEY"
        fi
        
        # Quick performance check
        echo -e "\n${BLUE}Fetching current metrics...${NC}"
        
        # Get validator info from cluster
        # Try to find by both vote and validator identity pubkeys
        VALIDATOR_INFO=$(solana validators --url https://api.testnet.solana.com 2>/dev/null | grep -E "($VOTE_PUBKEY|$VALIDATOR_PUBKEY)" | head -1 || echo "")
        if [ ! -z "$VALIDATOR_INFO" ]; then
            SKIP_RATE=$(echo "$VALIDATOR_INFO" | awk '{print $10}')
            CREDITS=$(echo "$VALIDATOR_INFO" | awk '{print $8}')
            SUCCESS_RATE=$((100 - ${SKIP_RATE%\%}))
            echo -e "Skip Rate: ${SKIP_RATE}"
            echo -e "Success Rate: ${SUCCESS_RATE}%"
            echo -e "Credits Earned: ${CREDITS}"
        else
            echo -e "${YELLOW}Validator not yet visible in cluster (may take a few minutes)${NC}"
            echo -e "${YELLOW}Looking for Vote: $VOTE_PUBKEY${NC}"
            echo -e "${YELLOW}Looking for Identity: $VALIDATOR_PUBKEY${NC}"
        fi
        
        # System resources
        echo -e "\n${BLUE}System Resources:${NC}"
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
        echo -e "CPU Usage: ${CPU_USAGE}%"
        echo -e "Memory Usage: ${MEM_USAGE}%"
        
        # Recent log activity
        if [ -f "$VALIDATOR_DIR/logs/validator.log" ]; then
            echo -e "\n${BLUE}Recent Activity:${NC}"
            VOTE_COUNT=$(tail -100 "$VALIDATOR_DIR/logs/validator.log" 2>/dev/null | grep -c "voting" || echo 0)
            echo -e "Votes in last 100 log lines: $VOTE_COUNT"
        fi
        
    else
        echo -e "${YELLOW}✗ Validator Status: NOT RUNNING${NC}"
        echo -e "Start the validator with option 1"
    fi
    
    echo ""
    echo "Press Enter to return to menu..."
    read
}

# Main loop
while true; do
    clear
    echo "================================================"
    echo "   Solana Testnet Validator Optimizer v1.0"
    echo "================================================"
    echo ""
    
    # Quick status
    if pgrep -f solana-validator > /dev/null; then
        echo -e "${GREEN}● Validator is running${NC}"
    else
        echo -e "${YELLOW}○ Validator is not running${NC}"
    fi
    echo ""
    
    show_menu
    read -p "Enter choice: " choice
    
    if [ "$FIRST_RUN" = true ]; then
        case $choice in
            1)
                run_initial_setup
                FIRST_RUN=false
                echo "Press Enter to continue..."
                read
                ;;
            2)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo -e "${YELLOW}Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    else
        case $choice in
            1)
                echo -e "${GREEN}Starting/Restarting validator...${NC}"
                ./setup-validator.sh
                echo "Press Enter to continue..."
                read
                ;;
            2)
                echo -e "${GREEN}Starting Live Performance Dashboard...${NC}"
                echo -e "${YELLOW}This will update every 5 seconds. Press Ctrl+C to return.${NC}"
                sleep 2
                ./dashboard.sh
                ;;
            3)
                echo -e "${GREEN}Starting performance monitor...${NC}"
                ./monitor-votes.sh
                echo "Press Enter to continue..."
                read
                ;;
            4)
                echo -e "${GREEN}Starting auto-optimizer...${NC}"
                echo -e "${YELLOW}This will run continuously. Press Ctrl+C to stop.${NC}"
                sleep 2
                ./optimize-validator.sh --auto
                ;;
            5)
                echo -e "${GREEN}Generating performance report...${NC}"
                ./monitor-votes.sh --report
                echo "Press Enter to continue..."
                read
                ;;
            6)
                echo -e "${YELLOW}Stopping validator...${NC}"
                ./stop-validator.sh
                echo "Press Enter to continue..."
                read
                ;;
            7)
                run_status_dashboard
                ;;
            8)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo -e "${YELLOW}Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    fi
done
