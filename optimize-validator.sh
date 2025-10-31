#!/bin/bash

# Dynamic Optimization Tuner for Solana Validator
# Automatically adjusts parameters based on performance metrics

set -e

VALIDATOR_DIR="$HOME/solana-validator"
OPTIMIZATION_CONFIG="$VALIDATOR_DIR/optimization.conf"
METRICS_LOG="$VALIDATOR_DIR/logs/optimization_metrics.log"

# Current optimization parameters
declare -A CURRENT_PARAMS=(
    ["rpc_threads"]=16
    ["banking_threads"]=32
    ["tpu_coalesce_ms"]=2
    ["snapshot_interval"]=100
    ["vote_threads"]=2
)

# Optimization ranges
declare -A MIN_PARAMS=(
    ["rpc_threads"]=8
    ["banking_threads"]=16
    ["tpu_coalesce_ms"]=1
    ["snapshot_interval"]=50
    ["vote_threads"]=1
)

declare -A MAX_PARAMS=(
    ["rpc_threads"]=32
    ["banking_threads"]=64
    ["tpu_coalesce_ms"]=10
    ["snapshot_interval"]=500
    ["vote_threads"]=4
)

# Function to get current vote success rate
get_vote_success_rate() {
    local vote_pubkey=$(solana-keygen pubkey "$VALIDATOR_DIR/vote-account-keypair.json" 2>/dev/null)
    local validator_pubkey=$(solana-keygen pubkey "$VALIDATOR_DIR/validator-keypair.json" 2>/dev/null)
    
    # Try to find validator by both vote and identity pubkeys
    local validator_info=$(solana validators --url https://api.testnet.solana.com 2>/dev/null | grep -E "($vote_pubkey|$validator_pubkey)" | head -1 || echo "")
    
    if [ ! -z "$validator_info" ]; then
        local skip_rate=$(echo "$validator_info" | awk '{print $10}' | tr -d '%')
        local success_rate=$((100 - ${skip_rate:-100}))
        echo "$success_rate"
    else
        echo "0"
    fi
}

# Function to analyze system resources
analyze_system_resources() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "0")
    local mem_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}' 2>/dev/null || echo "0")
    local io_wait=$(top -bn1 | grep "Cpu(s)" | awk '{print $5}' | cut -d'%' -f1 2>/dev/null || echo "0")
    
    echo "CPU: $cpu_usage%, Memory: $mem_usage%, IO Wait: $io_wait%"
    
    # Return optimization hints based on resources
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        echo "HIGH_CPU"
    elif (( $(echo "$mem_usage > 80" | bc -l) )); then
        echo "HIGH_MEM"
    elif (( $(echo "$io_wait > 20" | bc -l) )); then
        echo "HIGH_IO"
    else
        echo "NORMAL"
    fi
}

# Function to optimize based on metrics
optimize_parameters() {
    local success_rate=$1
    local resource_state=$2
    local changed=false
    
    echo "Current vote success rate: $success_rate%"
    echo "Resource state: $resource_state"
    
    # Optimize based on success rate
    if [ "$success_rate" -lt 50 ]; then
        echo "Low success rate detected. Applying aggressive optimizations..."
        
        # Reduce TPU coalesce time for faster votes
        if [ "${CURRENT_PARAMS[tpu_coalesce_ms]}" -gt "${MIN_PARAMS[tpu_coalesce_ms]}" ]; then
            CURRENT_PARAMS[tpu_coalesce_ms]=$((CURRENT_PARAMS[tpu_coalesce_ms] - 1))
            changed=true
            echo "  - Reduced TPU coalesce to ${CURRENT_PARAMS[tpu_coalesce_ms]}ms"
        fi
        
        # Increase vote threads
        if [ "${CURRENT_PARAMS[vote_threads]}" -lt "${MAX_PARAMS[vote_threads]}" ]; then
            CURRENT_PARAMS[vote_threads]=$((CURRENT_PARAMS[vote_threads] + 1))
            changed=true
            echo "  - Increased vote threads to ${CURRENT_PARAMS[vote_threads]}"
        fi
        
        # Increase RPC threads if resources allow
        if [ "$resource_state" != "HIGH_CPU" ] && [ "${CURRENT_PARAMS[rpc_threads]}" -lt "${MAX_PARAMS[rpc_threads]}" ]; then
            CURRENT_PARAMS[rpc_threads]=$((CURRENT_PARAMS[rpc_threads] + 4))
            changed=true
            echo "  - Increased RPC threads to ${CURRENT_PARAMS[rpc_threads]}"
        fi
        
    elif [ "$success_rate" -lt 80 ]; then
        echo "Moderate success rate. Fine-tuning parameters..."
        
        # Adjust banking threads based on resources
        if [ "$resource_state" == "NORMAL" ] && [ "${CURRENT_PARAMS[banking_threads]}" -lt "${MAX_PARAMS[banking_threads]}" ]; then
            CURRENT_PARAMS[banking_threads]=$((CURRENT_PARAMS[banking_threads] + 8))
            changed=true
            echo "  - Increased banking threads to ${CURRENT_PARAMS[banking_threads]}"
        fi
        
    elif [ "$success_rate" -ge 95 ]; then
        echo "Excellent success rate! Optimizing for efficiency..."
        
        # Can reduce some resources if success rate is very high
        if [ "$resource_state" == "HIGH_CPU" ] && [ "${CURRENT_PARAMS[banking_threads]}" -gt "${MIN_PARAMS[banking_threads]}" ]; then
            CURRENT_PARAMS[banking_threads]=$((CURRENT_PARAMS[banking_threads] - 8))
            changed=true
            echo "  - Reduced banking threads to ${CURRENT_PARAMS[banking_threads]} to save CPU"
        fi
    fi
    
    # Resource-based optimizations
    case "$resource_state" in
        HIGH_IO)
            # Increase snapshot interval to reduce IO
            if [ "${CURRENT_PARAMS[snapshot_interval]}" -lt "${MAX_PARAMS[snapshot_interval]}" ]; then
                CURRENT_PARAMS[snapshot_interval]=$((CURRENT_PARAMS[snapshot_interval] + 50))
                changed=true
                echo "  - Increased snapshot interval to ${CURRENT_PARAMS[snapshot_interval]} slots"
            fi
            ;;
        HIGH_MEM)
            # Reduce memory-intensive operations
            if [ "${CURRENT_PARAMS[snapshot_interval]}" -gt "${MIN_PARAMS[snapshot_interval]}" ]; then
                CURRENT_PARAMS[snapshot_interval]=$((CURRENT_PARAMS[snapshot_interval] - 25))
                changed=true
                echo "  - Decreased snapshot interval to ${CURRENT_PARAMS[snapshot_interval]} slots"
            fi
            ;;
    esac
    
    echo "$changed"
}

# Function to save optimization config
save_config() {
    {
        echo "# Solana Validator Optimization Configuration"
        echo "# Generated: $(date)"
        echo ""
        for key in "${!CURRENT_PARAMS[@]}"; do
            echo "$key=${CURRENT_PARAMS[$key]}"
        done
    } > "$OPTIMIZATION_CONFIG"
    
    echo "Configuration saved to $OPTIMIZATION_CONFIG"
}

# Function to apply optimizations (requires restart)
apply_optimizations() {
    echo "Applying new optimization parameters..."
    
    # Create optimized restart script
    cat > "$VALIDATOR_DIR/restart-optimized.sh" << EOF
#!/bin/bash
# Auto-generated optimized restart script

echo "Restarting validator with optimized parameters..."

# Stop validator
$PWD/stop-validator.sh

sleep 5

# Start with new parameters
VALIDATOR_DIR="$VALIDATOR_DIR"
VALIDATOR_KEYPAIR="\$VALIDATOR_DIR/validator-keypair.json"
VOTE_ACCOUNT_KEYPAIR="\$VALIDATOR_DIR/vote-account-keypair.json"
LEDGER_DIR="\$VALIDATOR_DIR/ledger"
ACCOUNTS_DIR="\$VALIDATOR_DIR/accounts"
SNAPSHOTS_DIR="\$VALIDATOR_DIR/snapshots"
LOG_DIR="\$VALIDATOR_DIR/logs"

nohup solana-validator \\
    --identity "\$VALIDATOR_KEYPAIR" \\
    --vote-account "\$VOTE_ACCOUNT_KEYPAIR" \\
    --ledger "\$LEDGER_DIR" \\
    --accounts "\$ACCOUNTS_DIR" \\
    --snapshots "\$SNAPSHOTS_DIR" \\
    --log "\$LOG_DIR/validator.log" \\
    --rpc-port 8899 \\
    --rpc-bind-address 127.0.0.1 \\
    --dynamic-port-range 8000-8020 \\
    --gossip-port 8001 \\
    --entrypoint entrypoint.testnet.solana.com:8001 \\
    --entrypoint entrypoint2.testnet.solana.com:8001 \\
    --entrypoint entrypoint3.testnet.solana.com:8001 \\
    --known-validator 5D1fNXzvv5NjV1ysLjirC4WY92RNsVH18vjmcszZd8on \\
    --known-validator 7XSY3MrYnK8vq693Rju17bbPkCN3Z7KvvfvJx4kdrsSY \\
    --known-validator Ft5fbkqNa76vnsjYNwjDZUXoTWpP7VYm3mtsaQckQADN \\
    --known-validator 9QxCLckBiJc783jnMvXZubK4wH86Eqqvashtrwvcsgkv \\
    --expected-genesis-hash 4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY \\
    --wal-recovery-mode skip_any_corrupted_record \\
    --limit-ledger-size 50000000 \\
    --accounts-db-caching-enabled \\
    --no-port-check \\
    --no-poh-speed-test \\
    --no-os-network-limits-test \\
    --full-rpc-api \\
    --rpc-threads ${CURRENT_PARAMS[rpc_threads]} \\
    --tpu-coalesce-ms ${CURRENT_PARAMS[tpu_coalesce_ms]} \\
    --max-genesis-archive-unpacked-size 1073741824 \\
    --snapshot-interval-slots ${CURRENT_PARAMS[snapshot_interval]} \\
    --full-snapshot-interval-slots 25000 \\
    --accounts-hash-interval-slots 100 \\
    --account-index program-id \\
    --account-index spl-token-owner \\
    --account-index spl-token-mint \\
    --skip-startup-ledger-verification \\
    --use-snapshot-archives-at-startup when-newest \\
    --block-production-method central-scheduler \\
    --accounts-index-threads ${CURRENT_PARAMS[banking_threads]} \\
    --tpu-enable-udp \\
    --allow-private-addr \\
    --enable-rpc-transaction-history \\
    --enable-extended-tx-metadata-storage \\
    --rpc-scan-and-fix-roots \\
    > "\$LOG_DIR/validator.out" 2>&1 &

echo "Validator restarted with optimized parameters!"
echo "New parameters:"
echo "  RPC Threads: ${CURRENT_PARAMS[rpc_threads]}"
echo "  Banking Threads: ${CURRENT_PARAMS[banking_threads]}"
echo "  TPU Coalesce: ${CURRENT_PARAMS[tpu_coalesce_ms]}ms"
echo "  Snapshot Interval: ${CURRENT_PARAMS[snapshot_interval]} slots"
echo "  Vote Threads: ${CURRENT_PARAMS[vote_threads]}"
EOF
    
    chmod +x "$VALIDATOR_DIR/restart-optimized.sh"
    
    echo "Restart script created. Run $VALIDATOR_DIR/restart-optimized.sh to apply optimizations."
}

# Function to run auto-tuning loop
auto_tune() {
    echo "Starting auto-tuning process..."
    echo "This will monitor and optimize parameters every 5 minutes."
    echo "Press Ctrl+C to stop."
    
    while true; do
        echo ""
        echo "=== Auto-Tuning Cycle $(date) ==="
        
        # Get current metrics
        local success_rate=$(get_vote_success_rate)
        local resource_state=$(analyze_system_resources | tail -1)
        
        # Log metrics
        echo "$(date),success_rate=$success_rate,resource_state=$resource_state" >> "$METRICS_LOG"
        
        # Optimize parameters
        local changed=$(optimize_parameters "$success_rate" "$resource_state" | tail -1)
        
        if [ "$changed" == "true" ]; then
            echo "Parameters changed. Saving configuration..."
            save_config
            apply_optimizations
            
            echo ""
            echo "IMPORTANT: Restart required to apply optimizations!"
            echo "Run: $VALIDATOR_DIR/restart-optimized.sh"
            echo ""
        else
            echo "No parameter changes needed."
        fi
        
        echo "Next check in 5 minutes..."
        sleep 300
    done
}

# Main function
main() {
    echo "============================================"
    echo "    Solana Validator Dynamic Optimizer"
    echo "============================================"
    
    # Check if validator is running
    if ! pgrep -f solana-validator > /dev/null; then
        echo "Error: Validator is not running. Start it first with ./setup-validator.sh"
        exit 1
    fi
    
    # Parse command line arguments
    case "$1" in
        --auto|-a)
            auto_tune
            ;;
        --once|-o)
            echo "Running single optimization cycle..."
            success_rate=$(get_vote_success_rate)
            resource_state=$(analyze_system_resources | tail -1)
            optimize_parameters "$success_rate" "$resource_state"
            save_config
            apply_optimizations
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --auto, -a     Run continuous auto-tuning"
            echo "  --once, -o     Run single optimization cycle"
            echo "  --help, -h     Show this help message"
            ;;
        *)
            echo "Interactive optimization mode"
            echo ""
            echo "Current metrics:"
            echo "  Vote success rate: $(get_vote_success_rate)%"
            echo "  System resources: $(analyze_system_resources)"
            echo ""
            echo "Options:"
            echo "1) Run auto-tuning (continuous)"
            echo "2) Run single optimization"
            echo "3) View current parameters"
            echo "4) Exit"
            echo ""
            read -p "Select option: " option
            
            case "$option" in
                1) auto_tune ;;
                2) $0 --once ;;
                3) 
                    if [ -f "$OPTIMIZATION_CONFIG" ]; then
                        cat "$OPTIMIZATION_CONFIG"
                    else
                        echo "No optimization config found."
                    fi
                    ;;
                4) exit 0 ;;
                *) echo "Invalid option" ;;
            esac
            ;;
    esac
}

# Create logs directory
mkdir -p "$VALIDATOR_DIR/logs"

# Run main function
main "$@"
