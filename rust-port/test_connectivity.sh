#!/bin/bash

echo "🔍 Testing Rust Optimizer Connectivity"
echo "======================================"
echo

echo "1. Testing Testnet Connection..."
solana epoch-info --url https://api.testnet.solana.com | head -5
echo

echo "2. Testing Rust Monitor..."
timeout 3 ./target/release/solana-validator-optimizer status 2>&1 || true
echo

echo "3. Testing Monitor Output..."
timeout 3 ./target/release/solana-validator-optimizer monitor 2>&1 | head -20
echo

echo "✅ Connectivity test complete"
