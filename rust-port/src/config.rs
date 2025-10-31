use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::fs;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidatorConfig {
    pub identity_keypair: PathBuf,
    pub vote_account_keypair: PathBuf,
    pub ledger_path: PathBuf,
    pub accounts_path: PathBuf,
    pub snapshots_path: PathBuf,
    pub log_path: PathBuf,
    pub rpc_port: u16,
    pub gossip_port: u16,
    pub optimization: OptimizationConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptimizationConfig {
    pub rpc_threads: u32,
    pub accounts_db_threads: u32,
    pub tpu_coalesce_ms: u32,
    pub incremental_snapshot_interval: u32,
    pub full_snapshot_interval: u32,
    pub limit_ledger_size: u64,
    pub accounts_db_cache_mb: u32,
    pub accounts_index_memory_mb: u32,
    pub udp_buffer_size: usize,
}

impl Default for ValidatorConfig {
    fn default() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        let base_path = PathBuf::from(&home).join("solana-validator");
        
        ValidatorConfig {
            identity_keypair: base_path.join("validator-keypair.json"),
            vote_account_keypair: base_path.join("vote-account-keypair.json"),
            ledger_path: base_path.join("ledger"),
            accounts_path: base_path.join("accounts"),
            snapshots_path: base_path.join("snapshots"),
            log_path: base_path.join("logs").join("validator.log"),
            rpc_port: 8899,
            gossip_port: 8001,
            optimization: OptimizationConfig::default(),
        }
    }
}

impl Default for OptimizationConfig {
    fn default() -> Self {
        OptimizationConfig {
            rpc_threads: 32,
            accounts_db_threads: 16,
            tpu_coalesce_ms: 1,
            incremental_snapshot_interval: 100,
            full_snapshot_interval: 25000,
            limit_ledger_size: 50_000_000,
            accounts_db_cache_mb: 4096,
            accounts_index_memory_mb: 2048,
            udp_buffer_size: 134217728, // 128MB
        }
    }
}

impl ValidatorConfig {
    pub fn load() -> Result<Self> {
        let config_path = Self::config_path();
        if config_path.exists() {
            let contents = fs::read_to_string(&config_path)?;
            Ok(serde_json::from_str(&contents)?)
        } else {
            let config = Self::default();
            config.save()?;
            Ok(config)
        }
    }

    pub fn save(&self) -> Result<()> {
        let config_path = Self::config_path();
        fs::create_dir_all(config_path.parent().unwrap())?;
        let contents = serde_json::to_string_pretty(self)?;
        fs::write(&config_path, contents)?;
        Ok(())
    }

    fn config_path() -> PathBuf {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        PathBuf::from(home).join(".solana-optimizer").join("config.json")
    }

    pub fn build_validator_args(&self) -> Vec<String> {
        vec![
            format!("--identity={}", self.identity_keypair.display()),
            format!("--vote-account={}", self.vote_account_keypair.display()),
            format!("--ledger={}", self.ledger_path.display()),
            format!("--accounts={}", self.accounts_path.display()),
            format!("--snapshots={}", self.snapshots_path.display()),
            format!("--log={}", self.log_path.display()),
            format!("--rpc-port={}", self.rpc_port),
            format!("--rpc-bind-address=127.0.0.1"),
            format!("--dynamic-port-range=8000-8020"),
            format!("--gossip-port={}", self.gossip_port),
            // Testnet entry points
            "--entrypoint=entrypoint.testnet.solana.com:8001".to_string(),
            "--entrypoint=entrypoint2.testnet.solana.com:8001".to_string(),
            "--entrypoint=entrypoint3.testnet.solana.com:8001".to_string(),
            // Known validators
            "--known-validator=5D1fNXzvv5NjV1ysLjirC4WY92RNsVH18vjmcszZd8on".to_string(),
            "--known-validator=7XSY3MrYnK8vq693Rju17bbPkCN3Z7KvvfvJx4kdrsSY".to_string(),
            // Optimizations
            format!("--rpc-threads={}", self.optimization.rpc_threads),
            format!("--accounts-db-threads={}", self.optimization.accounts_db_threads),
            format!("--tpu-coalesce-ms={}", self.optimization.tpu_coalesce_ms),
            format!("--incremental-snapshot-interval-slots={}", self.optimization.incremental_snapshot_interval),
            format!("--full-snapshot-interval-slots={}", self.optimization.full_snapshot_interval),
            format!("--limit-ledger-size={}", self.optimization.limit_ledger_size),
            format!("--accounts-db-cache-limit-mb={}", self.optimization.accounts_db_cache_mb),
            format!("--accounts-index-memory-limit-mb={}", self.optimization.accounts_index_memory_mb),
            // Additional optimizations
            "--expected-genesis-hash=4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY".to_string(),
            "--wal-recovery-mode=skip_any_corrupted_record".to_string(),
            "--accounts-db-caching-enabled".to_string(),
            "--no-port-check".to_string(),
            "--no-poh-speed-test".to_string(),
            "--no-os-network-limits-test".to_string(),
            "--full-rpc-api".to_string(),
            "--skip-startup-ledger-verification".to_string(),
            "--use-snapshot-archives-at-startup=when-newest".to_string(),
            "--block-production-method=central-scheduler".to_string(),
        ]
    }
}
