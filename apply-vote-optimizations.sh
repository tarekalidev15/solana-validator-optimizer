#!/bin/bash

# Apply immediate optimizations for maximum vote success

echo "================================================"
echo "   Applying Vote Success Optimizations"
echo "================================================"

VALIDATOR_DIR="$HOME/solana-validator"

# 1. Network optimizations (macOS specific)
echo "1. Applying network optimizations..."
sudo sysctl -w net.inet.tcp.nodelay=1 2>/dev/null || true
sudo sysctl -w net.inet.tcp.mssdflt=1460 2>/dev/null || true
sudo sysctl -w net.inet.tcp.win_scale_factor=8 2>/dev/null || true

# 2. Process priority (give validator higher priority)
echo "2. Setting validator process priority..."
VALIDATOR_PID=$(pgrep -f solana-validator | head -1)
if [ ! -z "$VALIDATOR_PID" ]; then
    sudo renice -10 $VALIDATOR_PID 2>/dev/null || echo "   Could not set priority (need sudo)"
fi

# 3. Create optimized restart script
echo "3. Creating optimized restart script..."
cat > "$VALIDATOR_DIR/restart-max-votes.sh" << 'EOF'
#!/bin/bash

echo "Restarting with maximum vote success configuration..."

# Stop current validator
pkill -f solana-validator
sleep 5

# Export paths
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

VALIDATOR_DIR="$HOME/solana-validator"
VALIDATOR_BIN="$HOME/.local/share/solana/install/active_release/bin/solana-validator"

# Start with vote-optimized parameters
nohup $VALIDATOR_BIN \
    --identity "$VALIDATOR_DIR/validator-keypair.json" \
    --vote-account "$VALIDATOR_DIR/vote-account-keypair.json" \
    --ledger "$VALIDATOR_DIR/ledger" \
    --accounts "$VALIDATOR_DIR/accounts" \
    --snapshots "$VALIDATOR_DIR/snapshots" \
    --log "$VALIDATOR_DIR/logs/validator.log" \
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
    --rpc-threads 32 \
    --tpu-coalesce-ms 1 \
    --max-genesis-archive-unpacked-size 1073741824 \
    --incremental-snapshot-interval-slots 100 \
    --full-snapshot-interval-slots 25000 \
    --account-index program-id \
    --skip-startup-ledger-verification \
    --use-snapshot-archives-at-startup when-newest \
    --block-production-method central-scheduler \
    --no-wait-for-vote-to-start-leader \
    --tpu-use-quic \
    > "$VALIDATOR_DIR/logs/validator.out" 2>&1 &

echo "Validator PID: $!"
echo $! > "$VALIDATOR_DIR/validator.pid"

echo "✅ Validator restarted with maximum vote optimization!"
EOF

chmod +x "$VALIDATOR_DIR/restart-max-votes.sh"

echo ""
echo "✅ Optimizations Applied!"
echo ""
echo "Key optimizations for vote success:"
echo "  • TPU Coalesce: 1ms (minimum latency)"
echo "  • RPC Threads: 32 (maximum processing)"
echo "  • QUIC enabled for faster transmission"
echo "  • Skip wait for vote to start leader"
echo ""
echo "To apply ALL optimizations, restart with:"
echo "  $VALIDATOR_DIR/restart-max-votes.sh"
echo ""
echo "Monitor your vote success with:"
echo "  watch -n 5 'solana validators --url https://api.testnet.solana.com | grep 9F3X'"
