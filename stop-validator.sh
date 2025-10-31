#!/bin/bash

# Stop Solana Validator Script

VALIDATOR_DIR="$HOME/solana-validator"
PID_FILE="$VALIDATOR_DIR/validator.pid"

echo "Stopping Solana Validator..."

# Try to stop gracefully using PID file
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping validator process (PID: $PID)..."
        kill -TERM "$PID"
        sleep 5
        
        # Force kill if still running
        if kill -0 "$PID" 2>/dev/null; then
            echo "Force stopping validator..."
            kill -KILL "$PID"
        fi
        
        rm -f "$PID_FILE"
        echo "Validator stopped."
    else
        echo "Validator process not found with PID: $PID"
        rm -f "$PID_FILE"
    fi
else
    echo "PID file not found."
fi

# Check if validator is running (both full and test validators)
if pgrep -f "solana-validator" > /dev/null || pgrep -f "solana-test-validator" > /dev/null; then
    echo "Stopping Solana validator..."
    pkill -f "solana-validator" 2>/dev/null
    pkill -f "solana-test-validator" 2>/dev/null
    sleep 2
    
    # Verify stopped
    if ! pgrep -f "solana-validator" > /dev/null && ! pgrep -f "solana-test-validator" > /dev/null; then
        echo "Validator stopped successfully."
    else
        echo "Force stopping remaining processes..."
        pkill -9 -f "solana-validator" 2>/dev/null
        pkill -9 -f "solana-test-validator" 2>/dev/null
    fi
fi
