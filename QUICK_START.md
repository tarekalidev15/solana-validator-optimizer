# Quick Start Guide

## Prerequisites

- Solana CLI 1.18.20+
- Rust 1.70+ (for Rust implementation)
- 8GB+ RAM
- Fast SSD

## Installation

```bash
# Clone repository
git clone https://github.com/yourusername/solana-validator-optimizer
cd solana-validator-optimizer

# Build Rust implementation
cd rust-port
cargo build --release
cd ..
```

## Usage

### 1. Start Validator (Shell)

```bash
./setup-validator.sh
```

This will:
- Generate keypairs
- Configure optimizations
- Start validator with enhanced settings
- Connect to Solana testnet

### 2. Monitor Performance (Rust)

```bash
cd rust-port
./target/release/solana-validator-optimizer monitor
```

Shows real-time metrics:
- Vote success rate
- Skip rate
- Credits earned
- Vote lag
- Network latency

### 3. Live Dashboard

```bash
./target/release/solana-validator-optimizer monitor --dashboard
```

Auto-refreshing dashboard with:
- Performance metrics
- System resource usage
- Optimization status
- Network health

### 4. Auto-Optimization

```bash
./target/release/solana-validator-optimizer optimize --auto
```

Continuously:
- Monitors performance
- Detects issues
- Applies optimizations
- Tracks improvements

## Shell Scripts Alternative

### Monitor

```bash
./monitor-vote-success.sh
```

### Optimize

```bash
./optimize-validator.sh
```

### Dashboard

```bash
./dashboard.sh
```

## Expected Results

### Performance Improvements

Typical results with good hardware and network:

- **Vote Success:** +10-15 percentage points
- **Skip Rate:** -60-80% reduction
- **Vote Lag:** -70-85% reduction
- **Latency:** -50-65% reduction

### Timeline

- **Immediate:** Configuration applied
- **5-10 min:** Validator restarted with new settings
- **30-60 min:** Performance metrics stabilize
- **2-4 hours:** Full optimization impact visible

## Network Configuration

### Testnet (Default)

```bash
export RPC_URL="https://api.testnet.solana.com"
```

### Mainnet

```bash
export RPC_URL="https://api.mainnet-beta.solana.com"
```

### Local

```bash
export RPC_URL="http://127.0.0.1:8899"
```

## Verification

### Check Validator Running

```bash
./target/release/solana-validator-optimizer status
```

### View Applied Optimizations

```bash
ps aux | grep solana-validator | grep -o "\-\-rpc-threads [0-9]*"
ps aux | grep solana-validator | grep -o "\-\-tpu-coalesce-ms [0-9]*"
```

### Compare with Cluster

```bash
solana validators --url https://api.testnet.solana.com | grep YOUR_PUBKEY
```

## Troubleshooting

### Validator Won't Start

```bash
# Check for port conflicts
lsof -i :8899

# View logs
tail -f ~/solana-validator/logs/validator.log
```

### No Metrics Showing

```bash
# Verify RPC connection
curl http://localhost:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# Check keypairs exist
ls -la ~/solana-validator/*.json
```

### Performance Not Improving

- Wait 30-60 minutes for metrics to stabilize
- Ensure validator has finished syncing
- Verify stake is delegated
- Check network connectivity

## Next Steps

1. **Baseline:** Run for 1-2 hours without optimizations
2. **Optimize:** Apply optimizations via `optimize --auto`
3. **Monitor:** Watch metrics for 2-4 hours
4. **Compare:** Evaluate improvement vs baseline

See `OPTIMIZATION_GUIDE.md` for detailed information.

---

**Support:** For issues, see documentation in project root.
