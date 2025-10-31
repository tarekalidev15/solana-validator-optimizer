# Solana Validator Setup Guide

## 🚀 Quick Start for Testnet

### Step 1: Install Dependencies
```bash
# Clone repository
git clone https://github.com/yourusername/solana-validator-optimizer.git
cd solana-validator-optimizer

# Make scripts executable
chmod +x *.sh

# Install system dependencies
./install.sh
```

### Step 2: Install Solana Validator
```bash
# Download and install official Solana binaries
./download-validator.sh
```

### Step 3: Setup and Start Validator
```bash
# Configure and launch validator on testnet
./setup-validator.sh
```

### Step 4: Fund Your Validator
```bash
# Get testnet SOL (required for voting)
# Option 1: Use web faucet
# Visit: https://solfaucet.com
# Enter your validator address shown during setup

# Option 2: Use automated script
./request-airdrop.sh
```

### Step 5: Apply Optimizations
```bash
# Apply maximum vote success optimizations
./apply-vote-optimizations.sh

# Restart with optimized parameters
~/solana-validator/restart-max-votes.sh
```

### Step 6: Monitor Performance
```bash
# Live dashboard
./dashboard.sh

# Compare with other validators
./monitor-vote-success.sh

# Check sync status
solana catchup $(solana-keygen pubkey ~/solana-validator/validator-keypair.json) --url https://api.testnet.solana.com
```

## 🔧 Configuration Files

### Validator Keypairs
Located in `~/solana-validator/`:
- `validator-keypair.json` - Validator identity
- `vote-account-keypair.json` - Vote account
- `withdrawer-keypair.json` - Withdrawer authority

### Optimization Config
- `~/solana-validator/optimization.conf` - Current optimization parameters
- `~/solana-validator/restart-optimized.sh` - Apply optimizations script
- `~/solana-validator/restart-max-votes.sh` - Maximum vote optimization script

## 📊 Performance Targets

| Metric | Target | Current Setup |
|--------|--------|---------------|
| Vote Success Rate | >95% | Optimized for 95%+ |
| Skip Rate | <5% | TPU coalesce at 1ms |
| RPC Threads | 16-32 | Set to 32 |
| Network Latency | <50ms | Depends on location |
| Sync Time | 2-4 hours | Using snapshot download |

## 🌐 Network Support

### Testnet (Production Testing)
- **Network**: Solana Testnet
- **RPC**: https://api.testnet.solana.com
- **Entrypoints**: 
  - entrypoint.testnet.solana.com:8001
  - entrypoint2.testnet.solana.com:8001
  - entrypoint3.testnet.solana.com:8001
- **Genesis Hash**: 4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY

### Local Test Validator
For development/testing only:
```bash
# Uses solana-test-validator if full validator not available
# Automatically detected by setup script
```

## ⚠️ Important Notes

1. **Disk Space**: Validator requires 200GB+ free space
2. **Memory**: 16GB minimum, 32GB recommended
3. **Network**: Stable connection required
4. **Sync Time**: Initial sync takes 2-4 hours
5. **SOL Required**: Need testnet SOL to create vote account

## 🆘 Troubleshooting

### Validator Won't Start
```bash
# Check logs
tail -100 ~/solana-validator/logs/validator.out

# Verify installation
which solana-validator

# Reinstall if needed
./download-validator.sh
```

### Can't Get Airdrop
- Testnet airdrops are rate-limited
- Use web faucet: https://solfaucet.com
- Try again after few hours

### High Skip Rate
```bash
# Apply optimizations
./apply-vote-optimizations.sh

# Restart validator
~/solana-validator/restart-max-votes.sh
```

### Not Syncing
```bash
# Check network connectivity
ping api.testnet.solana.com

# Restart with fresh ledger
rm -rf ~/solana-validator/ledger/*
./setup-validator.sh
```
