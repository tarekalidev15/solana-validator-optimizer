#!/bin/bash

# Solana Validator Vote Success Optimizer
# Maximizes successful votes by tuning critical parameters

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

VALIDATOR_DIR="$HOME/solana-validator"
OPTIMIZATION_CONFIG="$VALIDATOR_DIR/optimization.conf"
METRICS_LOG="$VALIDATOR_DIR/logs/optimization_metrics.log"

# Critical parameters for vote success
RPC_THREADS=${RPC_THREADS:-16}
TPU_COALESCE_MS=${TPU_COALESCE_MS:-2}
SNAPSHOT_INTERVAL=${SNAPSHOT_INTERVAL:-100}

echo "================================================"
echo "   Solana Validator Vote Success Optimizer"
echo "================================================"
echo ""

# Function to check validator sync status
check_sync_status() {
    echo -e "${BLUE}Checking sync status...${NC}"
    
    # Get current slot
    LOCAL_SLOT=$(curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' 2>/dev/null | \
        grep -o '"result":[0-9]*' | cut -d: -f2 || echo "0")
    
    # Get network slot
    NETWORK_SLOT=$(solana slot --url https://api.testnet.solana.com 2>/dev/null || echo "0")
    
    if [ "$LOCAL_SLOT" != "0" ] && [ "$NETWORK_SLOT" != "0" ]; then
        SLOT_DIFF=$((NETWORK_SLOT - LOCAL_SLOT))
        echo "Local Slot: $LOCAL_SLOT"
        echo "Network Slot: $NETWORK_SLOT"
        echo "Difference: $SLOT_DIFF slots"
        
        if [ $SLOT_DIFF -lt 200 ]; then
            echo -e "${GREEN}✓ Validator is synced${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Validator is catching up${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Unable to determine sync status${NC}"
        return 1
    fi
}

# Function to get current vote metrics
get_vote_metrics() {
    local vote_pubkey=$(solana-keygen pubkey "$VALIDATOR_DIR/vote-account-keypair.json" 2>/dev/null)
    local validator_pubkey=$(solana-keygen pubkey "$VALIDATOR_DIR/validator-keypair.json" 2>/dev/null)
    
    # Try to find validator info
    local validator_info=$(solana validators --url https://api.testnet.solana.com 2>/dev/null | grep -E "($vote_pubkey|$validator_pubkey)" | head -1 || echo "")
    
    if [ ! -z "$validator_info" ]; then
        local skip_rate=$(echo "$validator_info" | awk '{print $10}' | tr -d '%')
        local success_rate=$((100 - ${skip_rate:-100}))
        echo "$success_rate"
    else
        echo "0"
    fi
}

# Function to analyze system performance
analyze_performance() {
    echo -e "\n${BOLD}${BLUE}System Performance Analysis${NC}"
    echo "================================"
    
    # CPU usage
    if [[ "$OSTYPE" == "darwin"* ]]; then
        CPU_USAGE=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | tr -d '%')
    else
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    fi
    
    # Memory usage
    if [[ "$OSTYPE" == "darwin"* ]]; then
        MEM_USAGE=$(top -l 1 | grep PhysMem | awk '{print $2}' | tr -d 'M' | awk '{printf "%.0f", $1/16384*100}')
    else
        MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    fi
    
    echo "CPU Usage: ${CPU_USAGE}%"
    echo "Memory Usage: ${MEM_USAGE}%"
    
    # Network latency to testnet
    echo -e "\n${CYAN}Network Latency:${NC}"
    ping -c 3 api.testnet.solana.com 2>/dev/null | grep "min/avg/max" || echo "Unable to measure latency"
}

# Function to apply vote optimizations
apply_vote_optimizations() {
    echo -e "\n${BOLD}${GREEN}Applying Vote Success Optimizations${NC}"
    echo "======================================"
    
    echo "Creating optimized configuration..."
    
    # Save optimization config
    cat > "$OPTIMIZATION_CONFIG" << EOF
# Solana Validator Vote Optimization Configuration
# Generated: $(date)
# Goal: Maximize successful votes

# Critical for vote success
rpc_threads=$RPC_THREADS
tpu_coalesce_ms=$TPU_COALESCE_MS
snapshot_interval=$SNAPSHOT_INTERVAL

# Network optimizations
tcp_nodelay=1
tcp_quickack=1

# Recommended settings for vote success:
# - Low TPU coalesce (1-2ms) for faster vote transmission
# - High RPC threads (16-32) for better processing
# - Moderate snapshot interval to reduce IO overhead
# - Ensure stable network connection with low latency
EOF

    echo -e "${GREEN}✓ Configuration saved${NC}"
    
    # Create restart script with optimized parameters
    cat > "$VALIDATOR_DIR/restart-optimized.sh" << 'EOF'
#!/bin/bash

echo "Restarting validator with vote-optimized parameters..."

# Stop validator
./stop-validator.sh

sleep 5

# Export paths
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

VALIDATOR_DIR="$HOME/solana-validator"
VALIDATOR_KEYPAIR="$VALIDATOR_DIR/validator-keypair.json"
VOTE_ACCOUNT_KEYPAIR="$VALIDATOR_DIR/vote-account-keypair.json"
LEDGER_DIR="$VALIDATOR_DIR/ledger"
ACCOUNTS_DIR="$VALIDATOR_DIR/accounts"
SNAPSHOTS_DIR="$VALIDATOR_DIR/snapshots"
LOG_DIR="$VALIDATOR_DIR/logs"

# Find validator binary
if [ -f "$HOME/.local/share/solana/install/active_release/bin/solana-validator" ]; then
    VALIDATOR_BIN="$HOME/.local/share/solana/install/active_release/bin/solana-validator"
else
    VALIDATOR_BIN="solana-validator"
fi

# Start with vote-optimized parameters
nohup $VALIDATOR_BIN \
    --identity "$VALIDATOR_KEYPAIR" \
    --vote-account "$VOTE_ACCOUNT_KEYPAIR" \
    --ledger "$LEDGER_DIR" \
    --accounts "$ACCOUNTS_DIR" \
    --snapshots "$SNAPSHOTS_DIR" \
    --log "$LOG_DIR/validator.log" \
    --rpc-port 8899 \
    --rpc-bind-address 127.0.0.1 \
    --dynamic-port-range 8000-8020 \
    --gossip-port 8001 \
    --entrypoint entrypoint.testnet.solana.com:8001 \
    --entrypoint entrypoint2.testnet.solana.com:8001 \
    --entrypoint entrypoint3.testnet.solana.com:8001 \
    --known-validator 5D1fNXzvv5NjV1ysLjirC4WY92RNsVH18vjmcszZd8on \
    --known-validator 7XSY3MrYnK8vq693Rju17bbPkCN3Z7KvvfvJx4kdrsSY \
    --known-validator Ft5fbkqNa76vnsjYNwjDZUXoTWpP7VYm3mtsaQckQADN \
    --known-validator 9QxCLckBiJc783jnMvXZubK4wH86Eqqvashtrwvcsgkv \
    --expected-genesis-hash 4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY \
    --wal-recovery-mode skip_any_corrupted_record \
    --limit-ledger-size 50000000 \
    --accounts-db-caching-enabled \
    --no-port-check \
    --no-poh-speed-test \
    --no-os-network-limits-test \
    --full-rpc-api \
    --rpc-threads 24 \
    --tpu-coalesce-ms 1 \
    --max-genesis-archive-unpacked-size 1073741824 \
    --incremental-snapshot-interval-slots 100 \
    --full-snapshot-interval-slots 25000 \
    --account-index program-id \
    --account-index spl-token-owner \
    --account-index spl-token-mint \
    --skip-startup-ledger-verification \
    --use-snapshot-archives-at-startup when-newest \
    --block-production-method central-scheduler \
    > "$LOG_DIR/validator.out" 2>&1 &

echo "Validator PID: $!"
echo $! > "$VALIDATOR_DIR/validator.pid"

echo "Validator restarted with optimized parameters!"
echo ""
echo "Optimizations applied:"
echo "  ✓ RPC Threads: 24 (increased for better processing)"
echo "  ✓ TPU Coalesce: 1ms (minimum for fastest vote transmission)"
echo "  ✓ Snapshot Interval: 100 slots (reduced IO overhead)"
echo ""
echo "Monitor performance with: ./dashboard.sh"
EOF

    chmod +x "$VALIDATOR_DIR/restart-optimized.sh"
    echo -e "\n${CYAN}Restart script created: $VALIDATOR_DIR/restart-optimized.sh${NC}"
}

# Function to provide optimization recommendations
provide_recommendations() {
    echo -e "\n${BOLD}${CYAN}📊 Vote Success Optimization Recommendations${NC}"
    echo "============================================="
    
    local success_rate=$(get_vote_metrics)
    
    echo -e "\n${BOLD}1. Network Optimization:${NC}"
    echo "   • Ensure stable, low-latency internet connection"
    echo "   • Use wired connection if possible (avoid WiFi)"
    echo "   • Check firewall allows UDP on port 8001-8020"
    
    echo -e "\n${BOLD}2. Hardware Recommendations:${NC}"
    echo "   • CPU: 8+ cores recommended"
    echo "   • RAM: 16GB+ for optimal performance"
    echo "   • SSD: Fast NVMe SSD for ledger storage"
    
    echo -e "\n${BOLD}3. Critical Parameter Tuning:${NC}"
    echo "   • ${GREEN}TPU Coalesce:${NC} 1-2ms (currently: ${TPU_COALESCE_MS}ms)"
    echo "     Lower = faster vote transmission"
    echo "   • ${GREEN}RPC Threads:${NC} 16-32 (currently: ${RPC_THREADS})"
    echo "     More threads = better request handling"
    echo "   • ${GREEN}Snapshot Interval:${NC} 100-200 (currently: ${SNAPSHOT_INTERVAL})"
    echo "     Lower = less IO overhead during voting"
    
    echo -e "\n${BOLD}4. Vote Account Setup:${NC}"
    if [ "$success_rate" == "0" ]; then
        echo -e "   ${YELLOW}⚠ Vote account not active yet${NC}"
        echo "   • Fund your validator with testnet SOL"
        echo "   • Run ./setup-validator.sh to create vote account"
    else
        echo -e "   ${GREEN}✓ Current success rate: ${success_rate}%${NC}"
    fi
    
    echo -e "\n${BOLD}5. Monitoring & Continuous Optimization:${NC}"
    echo "   • Run: ${CYAN}./dashboard.sh${NC} for live metrics"
    echo "   • Run: ${CYAN}./optimize-voting.sh --auto${NC} for continuous tuning"
    echo "   • Check logs: ${CYAN}tail -f $VALIDATOR_DIR/logs/validator.log${NC}"
}

# Function to run auto-tuning
auto_tune() {
    echo -e "${BOLD}${GREEN}Starting Auto-Tuning Mode${NC}"
    echo "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        echo "=== Optimization Cycle $(date '+%H:%M:%S') ==="
        
        # Check sync status
        if check_sync_status; then
            # Get current metrics
            local success_rate=$(get_vote_metrics)
            
            if [ "$success_rate" != "0" ]; then
                echo "Current vote success rate: ${success_rate}%"
                
                # Adjust parameters based on success rate
                if [ $success_rate -lt 80 ]; then
                    echo -e "${YELLOW}Low success rate detected. Applying aggressive optimizations...${NC}"
                    TPU_COALESCE_MS=1
                    RPC_THREADS=24
                    apply_vote_optimizations
                    echo -e "${CYAN}Consider restarting with: $VALIDATOR_DIR/restart-optimized.sh${NC}"
                elif [ $success_rate -lt 95 ]; then
                    echo "Moderate success rate. Fine-tuning..."
                    TPU_COALESCE_MS=2
                    RPC_THREADS=20
                fi
            else
                echo "Validator not yet voting. Waiting for vote account activation..."
            fi
        fi
        
        echo "Next check in 60 seconds..."
        sleep 60
    done
}

# Main execution
main() {
    case "$1" in
        --auto|-a)
            auto_tune
            ;;
        --apply|-p)
            apply_vote_optimizations
            echo -e "\n${GREEN}To apply changes, restart validator with:${NC}"
            echo "  $VALIDATOR_DIR/restart-optimized.sh"
            ;;
        *)
            # Default: analyze and recommend
            echo -e "${BOLD}Current Validator Status:${NC}"
            check_sync_status
            echo ""
            analyze_performance
            echo ""
            apply_vote_optimizations
            provide_recommendations
            
            echo -e "\n${BOLD}Options:${NC}"
            echo "  • Apply optimizations and restart: ${CYAN}$VALIDATOR_DIR/restart-optimized.sh${NC}"
            echo "  • Run auto-tuning: ${CYAN}./optimize-voting.sh --auto${NC}"
            echo "  • Monitor performance: ${CYAN}./dashboard.sh${NC}"
            ;;
    esac
}

main "$@"
