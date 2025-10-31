# Quick Installation Guide

## 🚀 One-Line Install & Run

```bash
chmod +x *.sh && ./run.sh
```

## 📋 Step-by-Step

1. **Extract the files** (if from zip)
```bash
unzip solana-validator-optimizer.zip
cd solana-validator-optimizer
```

2. **Make scripts executable**
```bash
chmod +x *.sh
```

3. **Run the master script**
```bash
./run.sh
```

This will:
- Install Solana CLI if needed
- Generate validator keypairs
- Request testnet SOL
- Start the optimized validator
- Show monitoring dashboard

## 🔧 Individual Components

- **Setup only**: `./setup-validator.sh`
- **Monitor only**: `./monitor-votes.sh`
- **Optimize only**: `./optimize-validator.sh`
- **Stop validator**: `./stop-validator.sh`

## 📊 Monitor Performance

Watch real-time metrics:
```bash
./monitor-votes.sh --continuous
```

## 🤖 Auto-Optimization

Enable dynamic tuning:
```bash
./optimize-validator.sh --auto
```

## 📤 Push to GitHub

Share your work:
```bash
./push-to-github.sh
```

## 💡 Tips

- Run on Ubuntu 20.04+ for best compatibility
- Ensure ports 8000-8020 and 8899 are available
- Use SSD storage for better performance
- 32GB+ RAM recommended for production

## ⚡ Performance Target

- Vote Success Rate: >90%
- Skip Rate: <10%
- Consistent credit earning

That's it! Your optimized validator should be running within minutes.
