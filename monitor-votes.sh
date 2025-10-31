#!/bin/bash

# Vote Success Monitor for Solana Validator
# Tracks and optimizes vote success rate

set -e

VALIDATOR_DIR="$HOME/solana-validator"
VALIDATOR_KEYPAIR="$VALIDATOR_DIR/validator-keypair.json"
VOTE_ACCOUNT_KEYPAIR="$VALIDATOR_DIR/vote-account-keypair.json"
LOG_DIR="$VALIDATOR_DIR/logs"
METRICS_FILE="$LOG_DIR/vote_metrics.csv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize metrics file with headers if it doesn't exist
if [ ! -f "$METRICS_FILE" ]; then
    echo "timestamp,vote_success_rate,credits_earned,skip_rate,tower_votes,optimistic_slot_diff,root_slot_diff" > "$METRICS_FILE"
fi

# Function to get validator info
get_validator_info() {
    local validator_pubkey=$(solana-keygen pubkey "$VALIDATOR_KEYPAIR" 2>/dev/null)
    local vote_pubkey=$(solana-keygen pubkey "$VOTE_ACCOUNT_KEYPAIR" 2>/dev/null)
    
    echo -e "${BLUE}Validator Identity:${NC} $validator_pubkey"
    echo -e "${BLUE}Vote Account:${NC} $vote_pubkey"
}

# Function to check validator status
check_validator_status() {
    if pgrep -f solana-validator > /dev/null; then
        echo -e "${GREEN}✓ Validator is running${NC}"
        return 0
    else
        echo -e "${RED}✗ Validator is not running${NC}"
        return 1
    fi
}

# Function to get vote performance metrics
get_vote_metrics() {
    local vote_pubkey=$(solana-keygen pubkey "$VOTE_ACCOUNT_KEYPAIR" 2>/dev/null)
    local validator_pubkey=$(solana-keygen pubkey "$VALIDATOR_KEYPAIR" 2>/dev/null)
    
    # Get validator info from cluster - try both vote and identity pubkeys
    local validator_info=$(solana validators --url https://api.testnet.solana.com 2>/dev/null | grep -E "($vote_pubkey|$validator_pubkey)" | head -1 || echo "")
    
    if [ -z "$validator_info" ]; then
        echo -e "${YELLOW}Validator not yet visible in cluster${NC}"
        echo -e "${YELLOW}Looking for Vote: $vote_pubkey${NC}"
        echo -e "${YELLOW}Looking for Identity: $validator_pubkey${NC}"
        return 1
    fi
    
    # Parse metrics from validator info
    local credits=$(echo "$validator_info" | awk '{print $8}')
    local skip_rate=$(echo "$validator_info" | awk '{print $10}' | tr -d '%')
    local version=$(echo "$validator_info" | awk '{print $11}')
    
    # Get vote account info
    local vote_info=$(solana vote-account "$vote_pubkey" --url https://api.testnet.solana.com 2>/dev/null || echo "")
    
    if [ ! -z "$vote_info" ]; then
        local root_slot=$(echo "$vote_info" | grep "Root Slot:" | awk '{print $3}')
        local credits_current=$(echo "$vote_info" | grep "Credits:" | awk '{print $2}')
        local last_vote=$(echo "$vote_info" | grep "Last Vote:" | awk '{print $3}')
    fi
    
    # Get cluster info
    local slot_info=$(solana slot --url https://api.testnet.solana.com 2>/dev/null)
    
    # Calculate performance metrics
    local success_rate=$((100 - ${skip_rate:-0}))
    
    echo -e "\n${GREEN}=== Vote Performance Metrics ===${NC}"
    echo -e "Credits Earned: ${credits:-0}"
    echo -e "Skip Rate: ${skip_rate:-N/A}%"
    echo -e "Success Rate: ${success_rate}%"
    echo -e "Current Slot: ${slot_info:-N/A}"
    echo -e "Last Vote: ${last_vote:-N/A}"
    echo -e "Root Slot: ${root_slot:-N/A}"
    echo -e "Version: ${version:-N/A}"
    
    # Log metrics to file
    local timestamp=$(date +%s)
    echo "$timestamp,$success_rate,${credits:-0},${skip_rate:-0},${last_vote:-0},0,0" >> "$METRICS_FILE"
    
    return 0
}

# Function to get detailed performance stats
get_performance_stats() {
    local vote_pubkey=$(solana-keygen pubkey "$VOTE_ACCOUNT_KEYPAIR" 2>/dev/null)
    
    echo -e "\n${GREEN}=== Detailed Performance Stats ===${NC}"
    
    # Check RPC health
    local rpc_health=$(curl -s http://localhost:8899/health 2>/dev/null || echo "offline")
    echo -e "RPC Health: $rpc_health"
    
    # Get slot information
    local slot=$(curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' 2>/dev/null | \
        grep -o '"result":[0-9]*' | cut -d: -f2)
    echo -e "Current Slot: ${slot:-N/A}"
    
    # Get block production info
    local block_production=$(solana block-production --url https://api.testnet.solana.com --slot-limit 100 2>/dev/null | \
        grep "$vote_pubkey" || echo "No blocks produced yet")
    echo -e "Block Production: $block_production"
    
    # Check network latency to RPC endpoints
    echo -e "\n${BLUE}Network Latency:${NC}"
    ping -c 1 -W 1 api.testnet.solana.com 2>/dev/null | grep "time=" | cut -d= -f4 || echo "Unable to ping"
}

# Function to analyze vote patterns
analyze_vote_patterns() {
    echo -e "\n${GREEN}=== Vote Pattern Analysis ===${NC}"
    
    if [ -f "$LOG_DIR/validator.log" ]; then
        # Count vote attempts in last 1000 lines
        local vote_attempts=$(tail -1000 "$LOG_DIR/validator.log" 2>/dev/null | grep -c "voting" || echo 0)
        local vote_errors=$(tail -1000 "$LOG_DIR/validator.log" 2>/dev/null | grep -c "vote.*error" || echo 0)
        local vote_success=$((vote_attempts - vote_errors))
        
        echo -e "Recent Vote Attempts: $vote_attempts"
        echo -e "Vote Errors: $vote_errors"
        echo -e "Successful Votes: $vote_success"
        
        if [ $vote_attempts -gt 0 ]; then
            local success_percentage=$((vote_success * 100 / vote_attempts))
            echo -e "Success Percentage: $success_percentage%"
            
            # Provide optimization recommendations based on success rate
            if [ $success_percentage -lt 50 ]; then
                echo -e "\n${YELLOW}⚠ Low vote success rate detected!${NC}"
                echo "Recommendations:"
                echo "1. Check network connectivity and latency"
                echo "2. Increase --vote-only-retransmitter-threads"
                echo "3. Reduce --tpu-coalesce-ms for faster vote transmission"
                echo "4. Consider upgrading hardware or network connection"
            elif [ $success_percentage -lt 80 ]; then
                echo -e "\n${YELLOW}Vote success rate could be improved${NC}"
                echo "Consider:"
                echo "1. Fine-tuning banking threads"
                echo "2. Optimizing snapshot intervals"
                echo "3. Checking system resources"
            else
                echo -e "\n${GREEN}✓ Excellent vote success rate!${NC}"
            fi
        fi
    else
        echo "Log file not found. Validator may be starting up."
    fi
}

# Function to compare with other validators
compare_with_cluster() {
    echo -e "\n${GREEN}=== Cluster Comparison ===${NC}"
    
    # Get top validators by credits
    echo "Top 10 Validators by Credits (last epoch):"
    solana validators --url testnet --sort credits 2>/dev/null | head -15 || echo "Unable to fetch validator list"
    
    # Show our position
    local vote_pubkey=$(solana-keygen pubkey "$VOTE_ACCOUNT_KEYPAIR" 2>/dev/null)
    local our_position=$(solana validators --url testnet --sort credits 2>/dev/null | \
        grep -n "$vote_pubkey" | cut -d: -f1)
    
    if [ ! -z "$our_position" ]; then
        echo -e "\n${BLUE}Your validator position:${NC} #$our_position"
    fi
}

# Function to display optimization tips
show_optimization_tips() {
    echo -e "\n${GREEN}=== Active Optimizations ===${NC}"
    echo "✓ Using multiple entrypoints for redundancy"
    echo "✓ Increased RPC threads (16) for better vote processing"
    echo "✓ Optimized banking threads (32) for transaction processing"
    echo "✓ Accounts DB caching enabled for faster access"
    echo "✓ TPU coalescing reduced to 2ms for faster vote transmission"
    echo "✓ Vote-only retransmitter threads for dedicated vote handling"
    echo "✓ Skip startup verification for faster restarts"
    echo "✓ Central scheduler for optimized block production"
    
    echo -e "\n${BLUE}Additional Optimization Opportunities:${NC}"
    echo "• Ensure system has sufficient RAM (32GB+ recommended)"
    echo "• Use NVMe SSD for ledger storage"
    echo "• Optimize network: low latency, high bandwidth connection"
    echo "• Consider geographic proximity to other validators"
    echo "• Monitor and adjust snapshot intervals based on performance"
}

# Function to generate performance report
generate_report() {
    local report_file="$LOG_DIR/performance_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Solana Validator Performance Report"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        get_validator_info
        echo ""
        check_validator_status
        echo ""
        get_vote_metrics
        echo ""
        get_performance_stats
        echo ""
        analyze_vote_patterns
        echo ""
        show_optimization_tips
    } > "$report_file"
    
    echo -e "\n${GREEN}Report saved to: $report_file${NC}"
}

# Main monitoring loop
main() {
    clear
    echo "============================================"
    echo "    Solana Validator Vote Monitor"
    echo "============================================"
    
    # Check if validator is configured
    if [ ! -f "$VALIDATOR_KEYPAIR" ] || [ ! -f "$VOTE_ACCOUNT_KEYPAIR" ]; then
        echo -e "${RED}Error: Validator not configured. Run setup-validator.sh first.${NC}"
        exit 1
    fi
    
    # Display validator info
    get_validator_info
    echo ""
    
    # Check validator status
    if ! check_validator_status; then
        echo -e "${YELLOW}Start the validator with: ./setup-validator.sh${NC}"
        exit 1
    fi
    
    # Continuous monitoring mode
    if [ "$1" == "--continuous" ] || [ "$1" == "-c" ]; then
        echo -e "\n${BLUE}Starting continuous monitoring (Ctrl+C to stop)...${NC}"
        while true; do
            clear
            echo "============================================"
            echo "    Solana Validator Vote Monitor"
            echo "    $(date)"
            echo "============================================"
            get_validator_info
            check_validator_status
            get_vote_metrics
            get_performance_stats
            analyze_vote_patterns
            echo -e "\n${YELLOW}Refreshing in 30 seconds...${NC}"
            sleep 30
        done
    else
        # Single run mode
        get_vote_metrics
        get_performance_stats
        analyze_vote_patterns
        compare_with_cluster
        show_optimization_tips
        
        # Offer to generate report
        echo -e "\n${BLUE}Generate detailed report? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            generate_report
        fi
        
        echo -e "\n${YELLOW}Tip: Run with --continuous flag for real-time monitoring${NC}"
    fi
}

# Handle arguments
case "$1" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo "Options:"
        echo "  --continuous, -c    Run in continuous monitoring mode"
        echo "  --report, -r        Generate performance report"
        echo "  --help, -h          Show this help message"
        exit 0
        ;;
    --report|-r)
        generate_report
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
