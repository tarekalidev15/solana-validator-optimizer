# Solana Validator Optimizer - API Documentation

Complete reference for all public APIs, data structures, and integration patterns.

## Table of Contents

- [Smart Contract Optimizer](#smart-contract-optimizer)
- [Validator Manager](#validator-manager)
- [Configuration](#configuration)
- [Monitoring](#monitoring)
- [Blockchain Client](#blockchain-client)
- [Data Structures](#data-structures)

---

## Smart Contract Optimizer

**Module**: `src/smart_contract.rs`

### SmartContractOptimizer

Main interface for smart contract analysis and optimization.

#### Constructor

```rust
pub fn new(rpc_url: &str, program_id: Option<Pubkey>) -> Result<Self>
```

**Parameters:**
- `rpc_url: &str` - Solana RPC endpoint URL (testnet/mainnet/localhost)
- `program_id: Option<Pubkey>` - Optional program ID for default operations

**Returns:**
- `Result<SmartContractOptimizer>` - Initialized optimizer or error

**Example:**
```rust
use solana_sdk::pubkey::Pubkey;
use std::str::FromStr;

let rpc_url = "https://api.testnet.solana.com";
let program_id = Pubkey::from_str("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")?;

let optimizer = SmartContractOptimizer::new(rpc_url, Some(program_id))?;
```

**Errors:**
- RPC connection failure
- Invalid URL format

---

#### analyze_program

```rust
pub async fn analyze_program(&self, program_id: &Pubkey) -> Result<ProgramMetrics>
```

Performs comprehensive deep analysis of a Solana program.

**Parameters:**
- `program_id: &Pubkey` - The program to analyze

**Returns:**
- `Result<ProgramMetrics>` - Complete metrics structure

**Analysis Includes:**
- Compute unit usage patterns (up to 20 recent transactions)
- Account data size and rent costs
- CPI depth detection from logs
- Account lock contention analysis
- Data I/O estimation
- Optimization score calculation (0-100)

**Example:**
```rust
let program_id = Pubkey::from_str("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")?;
let metrics = optimizer.analyze_program(&program_id).await?;

println!("Optimization Score: {}/100", metrics.optimization_score);
println!("Average CU/tx: {:.0}", metrics.average_cu_per_tx);
println!("CPI Depth: {}", metrics.cpi_depth);
```

**Performance:**
- Typical runtime: 2-5 seconds
- RPC calls: 3-25 (depends on transaction count)
- Memory: < 1MB

**Errors:**
- RPC timeout
- Program not found
- Transaction parsing errors (gracefully degraded)

---

#### get_recommendations

```rust
pub fn get_recommendations(&self, metrics: &ProgramMetrics)
    -> Vec<OptimizationRecommendation>
```

Generates actionable optimization recommendations based on metrics.

**Parameters:**
- `metrics: &ProgramMetrics` - Metrics from `analyze_program()`

**Returns:**
- `Vec<OptimizationRecommendation>` - Prioritized list of recommendations

**Recommendation Types:**
1. Compute Unit Optimization (if avg_cu > 150k)
2. CPI Depth Optimization (if depth > 3)
3. Account Lock Contention (if max_locks > 15)
4. Account Data Size (if size > 100KB)
5. Data I/O Efficiency (if write_ratio > 0.5)
6. Transaction Batching (if tx_count > 100)
7. Instruction Density (if avg_instructions > 5)
8. Memory Layout (if account_size > 1KB)

**Example:**
```rust
let recommendations = optimizer.get_recommendations(&metrics);

for rec in recommendations {
    println!("{} Priority: {}",
        match rec.priority {
            Priority::High => "🔴",
            Priority::Medium => "🟡",
            Priority::Low => "🟢",
        },
        rec.category
    );
    println!("  {}", rec.description);
    println!("  Impact: {}", rec.estimated_improvement);
}
```

---

#### apply_optimizations

```rust
pub async fn apply_optimizations(&self, program_id: &Pubkey) -> Result<()>
```

Automatically applies safe optimizations to the program configuration.

**Parameters:**
- `program_id: &Pubkey` - Program to optimize

**Returns:**
- `Result<()>` - Success or error

**Applied Optimizations:**
1. **Compute Budget**: Adjusts CU limit to usage + 10% buffer
2. **Account Management**: Verifies rent exemption, minimizes sizes
3. **Transaction Batching**: Configures optimal batch sizes

**Example:**
```rust
optimizer.apply_optimizations(&program_id).await?;
// Output:
// ⚡ Applying Smart Contract Optimizations...
//   ▶ Optimizing compute budget...
//     ✓ Compute unit limit: Adjusted to actual usage + 10% buffer
//     ✓ Compute unit price: Set to competitive priority fee
//   ▶ Optimizing account management...
//     ✓ Account rent exemption: Verified
//     ✓ Account size: Minimized to required data only
//     ✓ PDA derivation: Using efficient seed patterns
//   ▶ Setting up transaction batching...
//     ✓ Batch size: Optimized for network conditions
//     ✓ Parallel execution: Enabled for independent transactions
```

**Safety:**
- All optimizations are non-destructive
- No state changes to blockchain
- Configuration suggestions only

---

#### monitor_program

```rust
pub async fn monitor_program(&self, program_id: &Pubkey) -> Result<()>
```

Real-time monitoring loop with 30-second updates.

**Parameters:**
- `program_id: &Pubkey` - Program to monitor

**Returns:**
- `Result<()>` - Never returns (runs until Ctrl+C)

**Behavior:**
- Analyzes program every 30 seconds
- Displays updated metrics
- Clears screen between updates
- Press Ctrl+C to stop

**Example:**
```rust
// Run in background or separate task
tokio::spawn(async move {
    optimizer.monitor_program(&program_id).await
});
```

---

#### display_metrics

```rust
pub fn display_metrics(&self, metrics: &ProgramMetrics)
```

Pretty-prints metrics to stdout with colors and formatting.

**Parameters:**
- `metrics: &ProgramMetrics` - Metrics to display

**Output Format:**
```
📈 Program Performance Metrics

  Compute Units:
    Used: 619470 CU
    Limit: 2000000 CU
    Average per TX: 619 CU
    Efficiency: 31.0%

  Account Data:
    Size: 134080 bytes (130.94 KB)

  Transactions:
    Count: 1000

  Optimization Score: 80/100
    Good, but room for improvement
```

---

#### display_recommendations

```rust
pub fn display_recommendations(&self, recommendations: &[OptimizationRecommendation])
```

Pretty-prints recommendations grouped by priority.

**Parameters:**
- `recommendations: &[OptimizationRecommendation]` - Recommendations to display

**Output Format:**
```
💡 Optimization Recommendations

  🔴 High Priority:
    • CPI Chain Depth: Deep CPI chain detected (4 levels)...
      Impact: 10% CU reduction per transaction

  🟡 Medium Priority:
    • Account Size: Large account detected (134KB)...
      Impact: 60-80% reduction in storage costs

  🟢 Low Priority:
    • Memory Layout: Optimize struct ordering...
      Impact: 15-25% reduction in serialization overhead
```

---

### Data Structures

#### ProgramMetrics

```rust
pub struct ProgramMetrics {
    pub compute_units_used: u64,
    pub compute_units_limit: u64,
    pub account_data_size: u64,
    pub transaction_count: u64,
    pub average_cu_per_tx: f64,
    pub optimization_score: f64,
    pub cpi_depth: u32,
    pub account_locks: HashMap<String, u64>,
    pub instruction_count: u64,
    pub data_reads_bytes: u64,
    pub data_writes_bytes: u64,
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `compute_units_used` | `u64` | Total CU consumed |
| `compute_units_limit` | `u64` | Total CU limit |
| `account_data_size` | `u64` | Program account size (bytes) |
| `transaction_count` | `u64` | Transactions analyzed |
| `average_cu_per_tx` | `f64` | Mean CU per transaction |
| `optimization_score` | `f64` | Score 0-100 |
| `cpi_depth` | `u32` | Max CPI depth |
| `account_locks` | `HashMap<String, u64>` | Pubkey → write count |
| `instruction_count` | `u64` | Total instructions |
| `data_reads_bytes` | `u64` | Estimated read I/O |
| `data_writes_bytes` | `u64` | Estimated write I/O |

---

#### OptimizationRecommendation

```rust
pub struct OptimizationRecommendation {
    pub category: String,
    pub priority: Priority,
    pub description: String,
    pub estimated_improvement: String,
}

pub enum Priority {
    High,
    Medium,
    Low,
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `category` | `String` | Category name (e.g., "Compute Units") |
| `priority` | `Priority` | High/Medium/Low |
| `description` | `String` | Detailed explanation with values |
| `estimated_improvement` | `String` | Quantified impact estimate |

**Priority Levels:**

| Priority | Criteria | Examples |
|----------|----------|----------|
| `High` | Critical issues | CU >90%, CPI depth >3, locks >15 |
| `Medium` | Important improvements | Account size >100KB, I/O ratio >0.5 |
| `Low` | Nice-to-have | Memory layout, instruction density |

---

#### TransactionAnalysis

```rust
pub struct TransactionAnalysis {
    pub signature: String,
    pub cu_consumed: u64,
    pub accounts_accessed: Vec<Pubkey>,
    pub writable_accounts: Vec<Pubkey>,
    pub instruction_count: usize,
    pub log_messages: Vec<String>,
    pub cpi_depth: u32,
}
```

**Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `signature` | `String` | Transaction signature |
| `cu_consumed` | `u64` | CU used by this tx |
| `accounts_accessed` | `Vec<Pubkey>` | All accounts (read/write) |
| `writable_accounts` | `Vec<Pubkey>` | Write-locked accounts |
| `instruction_count` | `usize` | Instructions in tx |
| `log_messages` | `Vec<String>` | Program logs |
| `cpi_depth` | `u32` | CPI depth for this tx |

---

### Helper Modules

#### compute_units

Compute unit optimization utilities.

```rust
pub mod compute_units {
    pub fn calculate_optimal_cu_limit(average_usage: u64) -> u64;
    pub fn create_compute_budget_instructions(
        cu_limit: u32,
        cu_price: u64
    ) -> Vec<Instruction>;
}
```

**Functions:**

##### calculate_optimal_cu_limit

```rust
pub fn calculate_optimal_cu_limit(average_usage: u64) -> u64
```

Calculates optimal CU limit with 10% buffer.

**Example:**
```rust
use solana_validator_optimizer_rs::smart_contract::compute_units;

let avg_usage = 150_000;
let optimal = compute_units::calculate_optimal_cu_limit(avg_usage);
// Returns: 165_000 (150k * 1.1)
```

##### create_compute_budget_instructions

```rust
pub fn create_compute_budget_instructions(
    cu_limit: u32,
    cu_price: u64
) -> Vec<Instruction>
```

Creates compute budget instructions for transactions.

**Parameters:**
- `cu_limit: u32` - Maximum CU for transaction
- `cu_price: u64` - Price in microlamports per CU

**Returns:**
- `Vec<Instruction>` - Two instructions (limit + price)

**Example:**
```rust
let instructions = compute_units::create_compute_budget_instructions(
    200_000,  // 200k CU limit
    1_000     // 1000 microlamports/CU
);

// Add to transaction:
let mut tx = Transaction::new_with_payer(&instructions, Some(&payer.pubkey()));
```

---

#### accounts

Account optimization utilities.

```rust
pub mod accounts {
    pub fn calculate_rent_exempt_balance(
        rpc_client: &RpcClient,
        data_len: usize
    ) -> Result<u64>;

    pub fn optimize_account_size(
        current_size: usize,
        required_size: usize
    ) -> usize;
}
```

**Functions:**

##### calculate_rent_exempt_balance

```rust
pub fn calculate_rent_exempt_balance(
    rpc_client: &RpcClient,
    data_len: usize
) -> Result<u64>
```

Calculates minimum balance for rent exemption.

**Example:**
```rust
use solana_validator_optimizer_rs::smart_contract::accounts;

let rent_exempt = accounts::calculate_rent_exempt_balance(&rpc_client, 1024)?;
println!("Need {} lamports for 1KB account", rent_exempt);
```

##### optimize_account_size

```rust
pub fn optimize_account_size(
    current_size: usize,
    required_size: usize
) -> usize
```

Optimizes account size with 8-byte alignment.

**Example:**
```rust
let optimized = accounts::optimize_account_size(1000, 997);
// Returns: 1000 (nearest multiple of 8)
```

---

#### batching

Transaction batching utilities.

```rust
pub mod batching {
    pub fn calculate_optimal_batch_size(
        network_tps: u64,
        target_confirmation_time_ms: u64
    ) -> usize;

    pub fn group_independent_transactions(
        transactions: Vec<Transaction>
    ) -> Vec<Vec<Transaction>>;
}
```

**Functions:**

##### calculate_optimal_batch_size

```rust
pub fn calculate_optimal_batch_size(
    network_tps: u64,
    target_confirmation_time_ms: u64
) -> usize
```

Calculates optimal batch size based on network conditions.

**Parameters:**
- `network_tps: u64` - Network transactions per second
- `target_confirmation_time_ms: u64` - Desired confirmation time

**Returns:**
- `usize` - Optimal batch size (capped at 4-64)

**Example:**
```rust
use solana_validator_optimizer_rs::smart_contract::batching;

let batch_size = batching::calculate_optimal_batch_size(
    2500,  // 2500 TPS
    5000   // 5 second target
);
// Returns: ~12 transactions per batch
```

##### group_independent_transactions

```rust
pub fn group_independent_transactions(
    transactions: Vec<Transaction>
) -> Vec<Vec<Transaction>>
```

Groups transactions for parallel execution.

**Example:**
```rust
let transactions = vec![tx1, tx2, tx3, tx4, tx5, tx6, tx7, tx8, tx9];
let batches = batching::group_independent_transactions(transactions);

for (i, batch) in batches.iter().enumerate() {
    println!("Batch {}: {} transactions", i, batch.len());
}
```

---

## Configuration

**Module**: `src/config.rs`

### OptimizerConfig

Configuration management for the optimizer.

```rust
pub struct OptimizerConfig {
    pub rpc_url: String,
    pub optimization: OptimizationSettings,
}

pub struct OptimizationSettings {
    pub rpc_threads: u32,
    pub accounts_db_threads: u32,
    pub tpu_coalesce_ms: u32,
    pub incremental_snapshot_interval: u32,
    pub full_snapshot_interval: u32,
    pub limit_ledger_size: u64,
    pub accounts_db_cache_mb: u64,
    pub accounts_index_memory_mb: u64,
    pub udp_buffer_size: u64,
}
```

#### load

```rust
pub fn load() -> Result<Self>
```

Loads configuration from `~/.solana-optimizer/config.json`.

**Example:**
```rust
use solana_validator_optimizer_rs::config::OptimizerConfig;

let config = OptimizerConfig::load()?;
println!("RPC URL: {}", config.rpc_url);
println!("RPC Threads: {}", config.optimization.rpc_threads);
```

#### save

```rust
pub fn save(&self) -> Result<()>
```

Saves configuration to disk.

**Example:**
```rust
let mut config = OptimizerConfig::load()?;
config.optimization.rpc_threads = 64;
config.save()?;
```

#### default

```rust
pub fn default() -> Self
```

Creates default configuration.

**Defaults:**
- RPC URL: `https://api.testnet.solana.com`
- RPC threads: 32
- Accounts DB threads: 16
- TPU coalesce: 1ms
- Snapshot intervals: 100 / 25000
- UDP buffer: 128MB

---

## CLI Integration

### Command Line Usage

```bash
# Analyze smart contract
solana-validator-optimizer analyze-contract <PROGRAM_ID> \
  --rpc-url https://api.testnet.solana.com

# Optimize smart contract
solana-validator-optimizer optimize-contract <PROGRAM_ID> \
  --rpc-url https://api.mainnet-beta.solana.com

# Monitor in real-time
solana-validator-optimizer monitor-contract <PROGRAM_ID> \
  --rpc-url https://api.testnet.solana.com
```

### Library Usage

```rust
use solana_validator_optimizer_rs::smart_contract::SmartContractOptimizer;
use solana_sdk::pubkey::Pubkey;
use std::str::FromStr;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize
    let rpc_url = "https://api.testnet.solana.com";
    let program_id = Pubkey::from_str("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")?;
    let optimizer = SmartContractOptimizer::new(rpc_url, Some(program_id))?;

    // Analyze
    let metrics = optimizer.analyze_program(&program_id).await?;
    optimizer.display_metrics(&metrics);

    // Get recommendations
    let recommendations = optimizer.get_recommendations(&metrics);
    optimizer.display_recommendations(&recommendations);

    // Apply optimizations
    optimizer.apply_optimizations(&program_id).await?;

    Ok(())
}
```

---

## Error Handling

### Error Types

All public APIs use `anyhow::Result<T>` for error handling.

**Common Errors:**

| Error | Cause | Solution |
|-------|-------|----------|
| `RPC connection failed` | Network issue or invalid URL | Check network, verify RPC URL |
| `Program not found` | Invalid program ID | Verify program ID is correct |
| `Transaction parsing failed` | Corrupted data | Gracefully degraded, uses defaults |
| `Insufficient transaction history` | New program | Uses conservative estimates |

**Example Error Handling:**

```rust
match optimizer.analyze_program(&program_id).await {
    Ok(metrics) => {
        println!("Score: {}", metrics.optimization_score);
    }
    Err(e) => {
        eprintln!("Analysis failed: {}", e);
        // Handle error appropriately
    }
}
```

---

## Performance Characteristics

### Benchmarks

| Operation | Time | RPC Calls | Memory |
|-----------|------|-----------|--------|
| `analyze_program()` | 2-5s | 3-25 | <1MB |
| `get_recommendations()` | <1ms | 0 | <100KB |
| `apply_optimizations()` | <100ms | 0 | <10KB |
| `monitor_program()` loop | 30s/iteration | 3-25 | <1MB |

### Optimization Tips

1. **Reuse RPC Client**: Create once, use multiple times
2. **Batch Analyses**: Analyze multiple programs concurrently
3. **Cache Results**: Store metrics if analyzing same program frequently
4. **Adjust Timeouts**: Increase for slow networks

**Example:**
```rust
// Good: Reuse client
let optimizer = SmartContractOptimizer::new(rpc_url, None)?;
for program_id in programs {
    let metrics = optimizer.analyze_program(&program_id).await?;
    // ...
}

// Bad: Create new client each time
for program_id in programs {
    let optimizer = SmartContractOptimizer::new(rpc_url, Some(program_id))?;
    // ...
}
```

---

## Version Compatibility

**Solana SDK**: 1.18.x
**Rust**: 1.70+
**Tokio**: 1.35+

### Breaking Changes

**v0.1.0 → Future**:
- Metrics structure may add new fields
- Recommendation categories may expand
- Scoring algorithm may be refined

**Compatibility Promise**:
- Public APIs will remain stable
- New fields will be additive
- Deprecations announced 1 version ahead

---

## Support & Resources

- **Documentation**: See [README.md](README.md)
- **Architecture**: See [SMART_CONTRACT_ARCHITECTURE.md](SMART_CONTRACT_ARCHITECTURE.md)
- **Test Results**: See [SMART_CONTRACT_TEST_RESULTS.md](SMART_CONTRACT_TEST_RESULTS.md)
- **Examples**: See `examples/` directory
- **Issues**: GitHub issue tracker

---

**API Version**: 1.0.0
**Last Updated**: 2025-11-01
**Stability**: Production-ready
