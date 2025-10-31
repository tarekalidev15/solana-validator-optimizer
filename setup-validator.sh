#!/bin/bash

# Solana Testnet Validator Setup with Optimizations
# This script sets up and runs an optimized Solana testnet validator

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "============================================"
echo "Solana Testnet Validator Optimizer"
echo "Maximizing Vote Success Rate"
echo "============================================"

# Configuration Variables
SOLANA_VERSION="1.18.17"
VALIDATOR_DIR="$HOME/solana-validator"
LEDGER_DIR="$VALIDATOR_DIR/ledger"
ACCOUNTS_DIR="$VALIDATOR_DIR/accounts"
SNAPSHOTS_DIR="$VALIDATOR_DIR/snapshots"
LOG_DIR="$VALIDATOR_DIR/logs"
VOTE_ACCOUNT_KEYPAIR="$VALIDATOR_DIR/vote-account-keypair.json"
VALIDATOR_KEYPAIR="$VALIDATOR_DIR/validator-keypair.json"
STAKE_ACCOUNT_KEYPAIR="$VALIDATOR_DIR/stake-account-keypair.json"

# Performance Optimization Settings
RPC_THREADS=16
BANKING_THREADS=32
MAX_GENESIS_ARCHIVE_UNPACKED_SIZE=1073741824
ACCOUNTS_DB_CACHING_ENABLED=true
SNAPSHOT_INTERVAL_SLOTS=100
FULL_SNAPSHOT_INTERVAL_SLOTS=25000

# Network Optimization
TCP_NODELAY=1
TCP_QUICKACK=1

# Create directories
mkdir -p $VALIDATOR_DIR $LEDGER_DIR $ACCOUNTS_DIR $SNAPSHOTS_DIR $LOG_DIR

# Function to check if Solana is installed
check_solana_installation() {
    # Add Solana to PATH if it exists
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    
    if ! command -v solana &> /dev/null; then
        echo "Solana CLI not found. Installing Solana v$SOLANA_VERSION..."
        sh -c "$(curl -sSfL https://release.solana.com/v$SOLANA_VERSION/install)"
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
        echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.zshrc
    else
        echo "Solana CLI found: $(solana --version)"
    fi
    
    # Check for solana-validator (required for testnet)
    if ! command -v solana-validator &> /dev/null && [ ! -f "$HOME/.local/share/solana/install/active_release/bin/solana-validator" ]; then
        echo -e "${RED}Error: solana-validator not found${NC}"
        echo "The full validator is required to connect to Solana testnet."
        echo ""
        echo "Your current Solana installation (likely from Homebrew) only includes test-validator."
        echo "To connect to the real testnet, you need the full validator."
        echo ""
        echo -e "${YELLOW}Please run:${NC}"
        echo "  ./install-validator.sh"
        echo ""
        echo "This will install the full Solana validator for testnet."
        echo "After installation, run this setup script again."
        exit 1
    elif [ -f "$HOME/.local/share/solana/install/active_release/bin/solana-validator" ]; then
        # Add the path explicitly if the validator exists but isn't in PATH
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        echo -e "${GREEN}✓ Full solana-validator found${NC}"
    fi
}

# Function to generate keypairs if they don't exist
generate_keypairs() {
    if [ ! -f "$VALIDATOR_KEYPAIR" ]; then
        echo "Generating validator keypair..."
        solana-keygen new --no-bip39-passphrase -o "$VALIDATOR_KEYPAIR"
    fi
    
    if [ ! -f "$VOTE_ACCOUNT_KEYPAIR" ]; then
        echo "Generating vote account keypair..."
        solana-keygen new --no-bip39-passphrase -o "$VOTE_ACCOUNT_KEYPAIR"
    fi
    
    if [ ! -f "$STAKE_ACCOUNT_KEYPAIR" ]; then
        echo "Generating stake account keypair..."
        solana-keygen new --no-bip39-passphrase -o "$STAKE_ACCOUNT_KEYPAIR"
    fi
}

# Function to configure system optimizations
configure_system_optimizations() {
    echo "Configuring system optimizations..."
    
    # Increase file descriptors (requires sudo)
    if [ "$EUID" -eq 0 ]; then
        echo "fs.file-max = 1000000" >> /etc/sysctl.conf
        echo "* soft nofile 1000000" >> /etc/security/limits.conf
        echo "* hard nofile 1000000" >> /etc/security/limits.conf
        sysctl -p
    else
        echo "Run with sudo for system-level optimizations"
        ulimit -n 65535 2>/dev/null || true
    fi
    
    # TCP optimizations for better network performance
    if [ "$EUID" -eq 0 ]; then
        sysctl -w net.core.rmem_max=134217728
        sysctl -w net.core.wmem_max=134217728
        sysctl -w net.core.rmem_default=134217728
        sysctl -w net.core.wmem_default=134217728
        sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728"
        sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"
        sysctl -w net.core.netdev_max_backlog=30000
        sysctl -w net.ipv4.tcp_congestion_control=bbr
        sysctl -w net.ipv4.tcp_notsent_lowat=16384
    fi
}

# Function to setup vote account
setup_vote_account() {
    echo "Setting up vote account..."
    
    # Configure for testnet
    solana config set --url https://api.testnet.solana.com
    
    # Check validator balance
    VALIDATOR_PUBKEY=$(solana-keygen pubkey "$VALIDATOR_KEYPAIR")
    echo "Validator pubkey: $VALIDATOR_PUBKEY"
    
    # Save pubkeys for reference
    echo "$VALIDATOR_PUBKEY" > "$VALIDATOR_DIR/validator-pubkey.txt"
    
    # Request airdrop for testnet (will fail if already has balance)
    echo "Requesting testnet SOL airdrop..."
    # Check current balance first
    BALANCE=$(solana balance "$VALIDATOR_PUBKEY" --url https://api.testnet.solana.com 2>/dev/null | awk '{print $1}' || echo "0")
    echo "Current balance: $BALANCE SOL"
    
    if (( $(echo "$BALANCE < 1" | bc -l) )); then
        echo "Requesting airdrop (max 1 SOL at a time)..."
        solana airdrop 1 "$VALIDATOR_PUBKEY" --url https://api.testnet.solana.com || {
            echo -e "${YELLOW}Airdrop failed. This is common due to rate limits.${NC}"
            echo "You can:"
            echo "  1. Run ./request-airdrop.sh for automatic retries"
            echo "  2. Use the testnet faucet: https://solfaucet.com"
            echo "  3. Continue anyway (validator will sync but not vote without SOL)"
            echo ""
            echo -e "${YELLOW}Your validator address:${NC} $VALIDATOR_PUBKEY"
            echo ""
        }
    else
        echo "Sufficient balance available, skipping airdrop."
    fi
    
    # Re-check balance after airdrop attempt
    BALANCE=$(solana balance "$VALIDATOR_PUBKEY" --url https://api.testnet.solana.com 2>/dev/null | awk '{print $1}' || echo "0")
    
    # Create vote account if it doesn't exist
    VOTE_PUBKEY=$(solana-keygen pubkey "$VOTE_ACCOUNT_KEYPAIR")
    echo "$VOTE_PUBKEY" > "$VALIDATOR_DIR/vote-pubkey.txt"
    
    if ! solana vote-account "$VOTE_PUBKEY" --url https://api.testnet.solana.com &>/dev/null; then
        # Check if we have enough balance to create vote account
        if (( $(echo "$BALANCE < 0.1" | bc -l) )); then
            echo -e "${YELLOW}Warning: Insufficient balance to create vote account (need at least 0.1 SOL)${NC}"
            echo "The validator will start but won't be able to vote until you:"
            echo "  1. Get SOL via ./request-airdrop.sh"
            echo "  2. Run this setup again to create the vote account"
        else
            echo "Creating vote account..."
            # Generate a separate withdrawer keypair if it doesn't exist
            WITHDRAWER_KEYPAIR="$VALIDATOR_DIR/withdrawer-keypair.json"
            if [ ! -f "$WITHDRAWER_KEYPAIR" ]; then
                echo "Generating withdrawer keypair..."
                solana-keygen new --no-bip39-passphrase -o "$WITHDRAWER_KEYPAIR" --silent
            fi
            
            solana create-vote-account \
                "$VOTE_ACCOUNT_KEYPAIR" \
                "$VALIDATOR_KEYPAIR" \
                "$WITHDRAWER_KEYPAIR" \
                --commission 10 \
                --url https://api.testnet.solana.com || echo -e "${YELLOW}Failed to create vote account. Will need to create it later.${NC}"
        fi
    else
        echo "Vote account already exists: $VOTE_PUBKEY"
    fi
    
    echo "Vote pubkey: $VOTE_PUBKEY"
}

# Function to start validator with optimizations
start_validator() {
    echo "Starting optimized validator..."
    
    # Ensure Solana is in PATH
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    
    # Kill any existing validator process
    pkill -f solana-validator || true
    sleep 2
    
    # Clear old ledger for fresh start (optional, comment out to preserve state)
    # rm -rf "$LEDGER_DIR"/*
    
    # For testnet, we need the full validator
    if command -v solana-validator &> /dev/null || [ -f "$HOME/.local/share/solana/install/active_release/bin/solana-validator" ]; then
        if [ -f "$HOME/.local/share/solana/install/active_release/bin/solana-validator" ]; then
            VALIDATOR_BIN="$HOME/.local/share/solana/install/active_release/bin/solana-validator"
        else
            VALIDATOR_BIN="solana-validator"
        fi
        echo -e "${GREEN}Starting validator for Solana testnet...${NC}"
    else
        echo -e "${RED}Error: solana-validator not found${NC}"
        echo "The full validator is required to connect to testnet."
        echo "Please run: ./install-validator.sh"
        return 1
    fi
    
    # Start validator for testnet
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
        --rpc-threads $RPC_THREADS \
        --tpu-coalesce-ms 2 \
        --max-genesis-archive-unpacked-size $MAX_GENESIS_ARCHIVE_UNPACKED_SIZE \
        --incremental-snapshot-interval-slots $SNAPSHOT_INTERVAL_SLOTS \
        --full-snapshot-interval-slots $FULL_SNAPSHOT_INTERVAL_SLOTS \
        --account-index program-id \
        --account-index spl-token-owner \
        --account-index spl-token-mint \
        --skip-startup-ledger-verification \
        --use-snapshot-archives-at-startup when-newest \
        --block-production-method central-scheduler \
        > "$LOG_DIR/validator.out" 2>&1 &
    
    echo "Validator PID: $!"
    echo $! > "$VALIDATOR_DIR/validator.pid"
    
    echo "Validator started! Logs: $LOG_DIR/validator.log"
    echo "Output: $LOG_DIR/validator.out"
}

# Main execution
main() {
    # Error handling
    set -e
    trap 'echo -e "\n${RED}Error occurred during setup. Check logs at $LOG_DIR${NC}"; exit 1' ERR
    
    echo "Step 1: Checking Solana installation..."
    check_solana_installation
    
    echo -e "\nStep 2: Generating keypairs..."
    generate_keypairs
    
    echo -e "\nStep 3: Configuring system optimizations..."
    configure_system_optimizations
    
    echo -e "\nStep 4: Setting up vote account..."
    setup_vote_account
    
    echo -e "\nStep 5: Starting optimized validator..."
    start_validator
    
    # Verify validator started
    sleep 3
    if pgrep -f "solana-validator" > /dev/null || pgrep -f "solana-test-validator" > /dev/null; then
        echo -e "\n${GREEN}✓ Validator process is running${NC}"
    else
        echo -e "\n${RED}✗ Validator failed to start. Check logs at $LOG_DIR/validator.out${NC}"
        exit 1
    fi
    
    echo -e "\n============================================"
    echo "${GREEN}Validator setup complete!${NC}"
    echo "Validator identity: $(solana-keygen pubkey $VALIDATOR_KEYPAIR)"
    echo "Vote account: $(solana-keygen pubkey $VOTE_ACCOUNT_KEYPAIR)"
    echo "Monitor with: ./dashboard.sh (Live Dashboard)"
    echo "           or: ./monitor-votes.sh (Classic)"
    echo "Optimize with: ./optimize-validator.sh"
    echo "Stop with: ./stop-validator.sh"
    echo "============================================"
}

# Run main function
main
