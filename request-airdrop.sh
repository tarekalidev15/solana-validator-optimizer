#!/bin/bash

# Helper script to request testnet SOL airdrop with retry logic

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
VALIDATOR_DIR="$HOME/solana-validator"
VALIDATOR_KEYPAIR="$VALIDATOR_DIR/validator-keypair.json"
MAX_RETRIES=3
RETRY_DELAY=10

# Check if keypair exists
if [ ! -f "$VALIDATOR_KEYPAIR" ]; then
    echo -e "${RED}Error: Validator keypair not found at $VALIDATOR_KEYPAIR${NC}"
    echo "Please run ./setup-validator.sh first"
    exit 1
fi

# Get validator pubkey
VALIDATOR_PUBKEY=$(solana-keygen pubkey "$VALIDATOR_KEYPAIR")
echo -e "${BLUE}Validator pubkey: $VALIDATOR_PUBKEY${NC}"

# Check current balance
echo -e "${BLUE}Checking current balance...${NC}"
BALANCE=$(solana balance "$VALIDATOR_PUBKEY" --url https://api.testnet.solana.com 2>/dev/null | awk '{print $1}' || echo "0")
echo -e "Current balance: ${GREEN}$BALANCE SOL${NC}"

if (( $(echo "$BALANCE >= 2" | bc -l) )); then
    echo -e "${GREEN}✓ Sufficient balance available (2+ SOL)${NC}"
    exit 0
fi

# Function to request airdrop with retries
request_airdrop() {
    local amount=$1
    local attempt=1
    
    while [ $attempt -le $MAX_RETRIES ]; do
        echo -e "${BLUE}Attempt $attempt/$MAX_RETRIES: Requesting $amount SOL...${NC}"
        
        if solana airdrop $amount "$VALIDATOR_PUBKEY" --url https://api.testnet.solana.com 2>&1 | tee /tmp/airdrop.log; then
            echo -e "${GREEN}✓ Airdrop successful!${NC}"
            return 0
        else
            if grep -q "rate limit" /tmp/airdrop.log; then
                echo -e "${YELLOW}Rate limit reached. Waiting $RETRY_DELAY seconds before retry...${NC}"
                sleep $RETRY_DELAY
            else
                echo -e "${YELLOW}Airdrop failed. Trying again in $RETRY_DELAY seconds...${NC}"
                sleep $RETRY_DELAY
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Main airdrop logic
echo -e "\n${BLUE}=== Requesting Testnet SOL Airdrop ===${NC}"
echo -e "${YELLOW}Note: Testnet airdrops are limited to 1 SOL per request${NC}"
echo -e "${YELLOW}      and have rate limits (max 2 requests per day)${NC}\n"

# Try to get 2 SOL total
NEEDED=$(echo "2 - $BALANCE" | bc)
echo -e "Need to request: ${BLUE}$NEEDED SOL${NC}"

if (( $(echo "$NEEDED > 0" | bc -l) )); then
    # Request 1 SOL at a time (testnet limit)
    if request_airdrop 1; then
        sleep 5
        NEW_BALANCE=$(solana balance "$VALIDATOR_PUBKEY" --url https://api.testnet.solana.com 2>/dev/null | awk '{print $1}' || echo "0")
        echo -e "New balance: ${GREEN}$NEW_BALANCE SOL${NC}"
        
        if (( $(echo "$NEW_BALANCE < 2" | bc -l) )); then
            echo -e "\n${BLUE}Requesting additional SOL...${NC}"
            sleep 10  # Wait before second request
            if request_airdrop 1; then
                FINAL_BALANCE=$(solana balance "$VALIDATOR_PUBKEY" --url https://api.testnet.solana.com 2>/dev/null | awk '{print $1}' || echo "0")
                echo -e "Final balance: ${GREEN}$FINAL_BALANCE SOL${NC}"
            fi
        fi
    else
        echo -e "\n${RED}Failed to get airdrop after $MAX_RETRIES attempts${NC}"
        echo -e "${YELLOW}Alternative options:${NC}"
        echo -e "  1. Wait a few hours and try again (rate limits reset)"
        echo -e "  2. Use a web faucet:"
        echo -e "     • https://solfaucet.com"
        echo -e "     • https://spl-token-faucet.com (for testnet)"
        echo -e "  3. Ask in Solana Discord #testnet-faucet channel"
        echo -e "\n${YELLOW}Your validator address to use in faucets:${NC}"
        echo -e "${BLUE}$VALIDATOR_PUBKEY${NC}"
    fi
fi

echo -e "\n${GREEN}Done!${NC}"
