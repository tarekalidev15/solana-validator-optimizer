#!/bin/bash

# Solana Validator Performance Dashboard
# Enhanced CLI dashboard with real-time metrics

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
VALIDATOR_DIR="$HOME/solana-validator"
VALIDATOR_KEYPAIR="$VALIDATOR_DIR/validator-keypair.json"
VOTE_ACCOUNT_KEYPAIR="$VALIDATOR_DIR/vote-account-keypair.json"
METRICS_FILE="$VALIDATOR_DIR/logs/metrics_history.csv"
REFRESH_INTERVAL=5

# Function to draw a line
draw_line() {
    printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' '='
}

# Function to center text
center_text() {
    local text="$1"
    local width=${COLUMNS:-80}
    local text_length=${#text}
    local padding=$(( (width - text_length) / 2 ))
    printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

# Function to format number with commas
format_number() {
    echo "$1" | sed ':a;s/\([0-9]\)\([0-9]\{3\}\)\($\|[^0-9]\)/\1,\2\3/;ta'
}

# Function to get validator metrics
get_validator_metrics() {
    local validator_pubkey=$(solana-keygen pubkey "$VALIDATOR_KEYPAIR" 2>/dev/null || echo "N/A")
    local vote_pubkey=$(solana-keygen pubkey "$VOTE_ACCOUNT_KEYPAIR" 2>/dev/null || echo "N/A")
    
    # Get validator info from cluster
    local validator_info=$(solana validators --url https://api.testnet.solana.com 2>/dev/null | grep -E "($vote_pubkey|$validator_pubkey)" | head -1 || echo "")
    
    if [ ! -z "$validator_info" ]; then
        SKIP_RATE=$(echo "$validator_info" | awk '{print $10}' | tr -d '%')
        CREDITS=$(echo "$validator_info" | awk '{print $8}')
        VERSION=$(echo "$validator_info" | awk '{print $11}')
        SUCCESS_RATE=$((100 - ${SKIP_RATE:-100}))
        STATUS="${GREEN}● ACTIVE${NC}"
    else
        SKIP_RATE="--"
        CREDITS="0"
        VERSION="--"
        SUCCESS_RATE="0"
        STATUS="${YELLOW}● SYNCING${NC}"
    fi
}

# Function to get system metrics
get_system_metrics() {
    # CPU usage
    if [[ "$OSTYPE" == "darwin"* ]]; then
        CPU_USAGE=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | tr -d '%')
    else
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    fi
    
    # Memory usage
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS memory calculation
        MEM_STATS=$(vm_stat | grep -E "Pages (active|wired down|occupied by compressor):" | awk '{print $NF}' | tr -d '.')
        MEM_USED=0
        for stat in $MEM_STATS; do
            MEM_USED=$((MEM_USED + stat))
        done
        # Convert pages to GB (page size is 4096 bytes)
        MEM_USED_GB=$(echo "scale=2; $MEM_USED * 4096 / 1073741824" | bc)
        TOTAL_MEM_GB=$(sysctl -n hw.memsize | awk '{printf "%.2f", $1/1073741824}')
        MEM_USAGE=$(echo "scale=0; $MEM_USED_GB / $TOTAL_MEM_GB * 100" | bc)
    else
        MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    fi
    
    # Disk usage
    DISK_USAGE=$(df -h "$VALIDATOR_DIR" | tail -1 | awk '{print $5}' | tr -d '%')
    
    # Network stats (validator process)
    if pgrep -f solana-validator > /dev/null; then
        NETWORK_STATUS="${GREEN}Connected${NC}"
    else
        NETWORK_STATUS="${RED}Disconnected${NC}"
    fi
}

# Function to get slot information
get_slot_info() {
    # Get current slot from local RPC
    CURRENT_SLOT=$(curl -s http://localhost:8899 -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' 2>/dev/null | \
        grep -o '"result":[0-9]*' | cut -d: -f2 || echo "N/A")
    
    # Get slot from testnet for comparison
    NETWORK_SLOT=$(solana slot --url https://api.testnet.solana.com 2>/dev/null || echo "N/A")
    
    # Calculate sync status
    if [ "$CURRENT_SLOT" != "N/A" ] && [ "$NETWORK_SLOT" != "N/A" ]; then
        SLOT_DIFF=$((NETWORK_SLOT - CURRENT_SLOT))
        if [ $SLOT_DIFF -lt 100 ]; then
            SYNC_STATUS="${GREEN}Synced${NC}"
        elif [ $SLOT_DIFF -lt 1000 ]; then
            SYNC_STATUS="${YELLOW}Catching up${NC}"
        else
            SYNC_STATUS="${RED}Behind${NC}"
        fi
    else
        SYNC_STATUS="${YELLOW}Unknown${NC}"
    fi
}

# Function to display the dashboard header
display_header() {
    clear
    echo -e "${BOLD}"
    draw_line
    center_text "🚀 SOLANA VALIDATOR OPTIMIZER DASHBOARD 🚀"
    draw_line
    echo -e "${NC}"
    
    # Display time and refresh info
    echo -e "${CYAN}Last Updated:${NC} $(date '+%Y-%m-%d %H:%M:%S') | ${CYAN}Auto-refresh:${NC} ${REFRESH_INTERVAL}s | Press ${BOLD}Ctrl+C${NC} to exit"
    echo ""
}

# Function to display validator info
display_validator_info() {
    echo -e "${BOLD}${BLUE}📊 VALIDATOR INFORMATION${NC}"
    draw_line
    
    local validator_pubkey=$(solana-keygen pubkey "$VALIDATOR_KEYPAIR" 2>/dev/null || echo "Not found")
    local vote_pubkey=$(solana-keygen pubkey "$VOTE_ACCOUNT_KEYPAIR" 2>/dev/null || echo "Not found")
    
    printf "%-20s %s\n" "Status:" "$STATUS"
    printf "%-20s ${CYAN}%s${NC}\n" "Identity:" "$validator_pubkey"
    printf "%-20s ${CYAN}%s${NC}\n" "Vote Account:" "$vote_pubkey"
    printf "%-20s %s\n" "Version:" "$VERSION"
    printf "%-20s %s\n" "Network:" "Testnet"
    echo ""
}

# Function to display performance metrics
display_performance_metrics() {
    echo -e "${BOLD}${BLUE}⚡ PERFORMANCE METRICS${NC}"
    draw_line
    
    # Success Rate with color coding
    if [ "$SUCCESS_RATE" != "0" ]; then
        if [ $SUCCESS_RATE -ge 95 ]; then
            SR_COLOR=$GREEN
        elif [ $SUCCESS_RATE -ge 80 ]; then
            SR_COLOR=$YELLOW
        else
            SR_COLOR=$RED
        fi
        printf "%-20s ${SR_COLOR}%s%%${NC}\n" "Vote Success Rate:" "$SUCCESS_RATE"
    else
        printf "%-20s %s\n" "Vote Success Rate:" "--"
    fi
    
    printf "%-20s %s%%\n" "Skip Rate:" "$SKIP_RATE"
    printf "%-20s %s\n" "Credits Earned:" "$(format_number $CREDITS)"
    printf "%-20s %s / %s\n" "Current/Network Slot:" "$CURRENT_SLOT" "$NETWORK_SLOT"
    printf "%-20s %s\n" "Sync Status:" "$SYNC_STATUS"
    echo ""
}

# Function to display system resources
display_system_resources() {
    echo -e "${BOLD}${BLUE}💻 SYSTEM RESOURCES${NC}"
    draw_line
    
    # CPU bar
    printf "%-15s [" "CPU Usage:"
    local cpu_bar_width=30
    local cpu_filled=$((CPU_USAGE * cpu_bar_width / 100))
    for ((i=0; i<cpu_filled; i++)); do printf "█"; done
    for ((i=cpu_filled; i<cpu_bar_width; i++)); do printf "░"; done
    
    if [ $CPU_USAGE -gt 80 ]; then
        printf "] ${RED}%3d%%${NC}\n" "$CPU_USAGE"
    elif [ $CPU_USAGE -gt 60 ]; then
        printf "] ${YELLOW}%3d%%${NC}\n" "$CPU_USAGE"
    else
        printf "] ${GREEN}%3d%%${NC}\n" "$CPU_USAGE"
    fi
    
    # Memory bar
    printf "%-15s [" "Memory Usage:"
    local mem_filled=$((MEM_USAGE * cpu_bar_width / 100))
    for ((i=0; i<mem_filled; i++)); do printf "█"; done
    for ((i=mem_filled; i<cpu_bar_width; i++)); do printf "░"; done
    
    if [ $MEM_USAGE -gt 80 ]; then
        printf "] ${RED}%3d%%${NC}\n" "$MEM_USAGE"
    elif [ $MEM_USAGE -gt 60 ]; then
        printf "] ${YELLOW}%3d%%${NC}\n" "$MEM_USAGE"
    else
        printf "] ${GREEN}%3d%%${NC}\n" "$MEM_USAGE"
    fi
    
    # Disk bar
    printf "%-15s [" "Disk Usage:"
    local disk_filled=$((DISK_USAGE * cpu_bar_width / 100))
    for ((i=0; i<disk_filled; i++)); do printf "█"; done
    for ((i=disk_filled; i<cpu_bar_width; i++)); do printf "░"; done
    
    if [ $DISK_USAGE -gt 80 ]; then
        printf "] ${RED}%3d%%${NC}\n" "$DISK_USAGE"
    elif [ $DISK_USAGE -gt 60 ]; then
        printf "] ${YELLOW}%3d%%${NC}\n" "$DISK_USAGE"
    else
        printf "] ${GREEN}%3d%%${NC}\n" "$DISK_USAGE"
    fi
    
    printf "%-15s %s\n" "Network:" "$NETWORK_STATUS"
    echo ""
}

# Function to display optimization status
display_optimization_status() {
    echo -e "${BOLD}${BLUE}🔧 OPTIMIZATION STATUS${NC}"
    draw_line
    
    if [ -f "$VALIDATOR_DIR/optimization.conf" ]; then
        source "$VALIDATOR_DIR/optimization.conf"
        printf "%-20s %s\n" "RPC Threads:" "${rpc_threads:-16}"
        printf "%-20s %s\n" "Banking Threads:" "${banking_threads:-32}"
        printf "%-20s %s ms\n" "TPU Coalesce:" "${tpu_coalesce_ms:-2}"
        printf "%-20s %s slots\n" "Snapshot Interval:" "${snapshot_interval:-100}"
        printf "%-20s %s\n" "Vote Threads:" "${vote_threads:-2}"
        
        # Check if optimizer is running
        if pgrep -f "optimize-validator.sh" > /dev/null; then
            printf "%-20s ${GREEN}● Running${NC}\n" "Auto-Optimizer:"
        else
            printf "%-20s ${YELLOW}○ Stopped${NC}\n" "Auto-Optimizer:"
        fi
    else
        echo "No optimization configuration found."
        echo "Run './optimize-validator.sh --auto' to start auto-optimization."
    fi
    echo ""
}

# Function to display recent logs
display_recent_activity() {
    echo -e "${BOLD}${BLUE}📜 RECENT ACTIVITY${NC}"
    draw_line
    
    if [ -f "$VALIDATOR_DIR/logs/validator.log" ]; then
        # Count recent votes
        RECENT_VOTES=$(tail -500 "$VALIDATOR_DIR/logs/validator.log" 2>/dev/null | grep -c "voting" || echo 0)
        printf "%-25s %d\n" "Votes (last 500 lines):" "$RECENT_VOTES"
        
        # Show last few important log entries
        echo -e "\n${CYAN}Last Log Entries:${NC}"
        tail -5 "$VALIDATOR_DIR/logs/validator.log" 2>/dev/null | sed 's/^/  /' || echo "  No logs available"
    else
        echo "No validator logs found."
    fi
    echo ""
}

# Function to save metrics to history
save_metrics() {
    if [ "$SUCCESS_RATE" != "0" ]; then
        echo "$(date +%s),$SUCCESS_RATE,$SKIP_RATE,$CREDITS,$CPU_USAGE,$MEM_USAGE,$DISK_USAGE" >> "$METRICS_FILE"
    fi
}

# Main dashboard loop
main() {
    # Check if validator directory exists
    if [ ! -d "$VALIDATOR_DIR" ]; then
        echo -e "${RED}Error: Validator directory not found at $VALIDATOR_DIR${NC}"
        echo "Please run './setup-validator.sh' first."
        exit 1
    fi
    
    # Create metrics file if it doesn't exist
    if [ ! -f "$METRICS_FILE" ]; then
        mkdir -p "$(dirname "$METRICS_FILE")"
        echo "timestamp,success_rate,skip_rate,credits,cpu,memory,disk" > "$METRICS_FILE"
    fi
    
    echo -e "${CYAN}Starting dashboard... Press Ctrl+C to exit.${NC}"
    
    # Main loop
    while true; do
        # Gather all metrics
        get_validator_metrics
        get_system_metrics
        get_slot_info
        
        # Display dashboard
        display_header
        display_validator_info
        display_performance_metrics
        display_system_resources
        display_optimization_status
        display_recent_activity
        
        # Save metrics
        save_metrics
        
        # Footer
        draw_line
        echo -e "${BOLD}${MAGENTA}Quick Actions:${NC}"
        echo "  • View detailed logs: tail -f $VALIDATOR_DIR/logs/validator.log"
        echo "  • Start optimizer: ./optimize-validator.sh --auto"
        echo "  • Stop validator: ./stop-validator.sh"
        echo ""
        echo -e "${CYAN}Refreshing in ${REFRESH_INTERVAL} seconds...${NC}"
        
        # Wait for refresh interval
        sleep $REFRESH_INTERVAL
    done
}

# Trap Ctrl+C to exit cleanly
trap 'echo -e "\n${CYAN}Dashboard stopped.${NC}"; exit 0' INT

# Run main function
main
