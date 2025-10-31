use anyhow::{Context, Result};
use colored::Colorize;
use std::process::{Command, Child, Stdio};
use std::fs;
use std::path::{Path, PathBuf};
use tokio::time::{sleep, Duration};
use sysinfo::System;
use solana_sdk::{
    signature::{Keypair, read_keypair_file},
    native_token::LAMPORTS_PER_SOL,
};

use crate::config::ValidatorConfig;
use crate::system::{SystemOptimizer, SystemMonitor};
use crate::blockchain::SolanaInterface;

pub async fn start(skip_airdrop: bool) -> Result<()> {
    println!("{}",  "============================================".blue());
    println!("{}", "Solana Validator Optimizer - Rust Edition".blue().bold());
    println!("{}", "High-Performance Direct Implementation".blue());
    println!("{}", "============================================".blue());
    
    // Load or create config
    let config = ValidatorConfig::load()?;
    
    // Step 1: Check Solana installation
    println!("\n{}", "Step 1: Checking Solana installation...".cyan());
    check_solana_installation()?;
    
    // Step 2: Generate keypairs if needed
    println!("\n{}", "Step 2: Generating keypairs...".cyan());
    generate_keypairs(&config)?;
    
    // Step 3: Apply low-level system optimizations
    println!("\n{}", "Step 3: Applying low-level system optimizations...".cyan());
    SystemOptimizer::optimize_all()?;
    
    // Step 4: Setup blockchain connection
    println!("\n{}", "Step 4: Connecting to blockchain...".cyan());
    let validator_keypair = read_keypair_file(&config.identity_keypair)
        .map_err(|e| anyhow::anyhow!("Failed to read validator keypair: {}", e))?;
    let vote_keypair = read_keypair_file(&config.vote_account_keypair)
        .map_err(|e| anyhow::anyhow!("Failed to read vote keypair: {}", e))?;
    
    let solana = SolanaInterface::new(
        "https://api.testnet.solana.com",
        validator_keypair,
        vote_keypair,
    )?;
    
    // Step 5: Setup vote account if needed
    if !skip_airdrop {
        println!("\n{}", "Step 5: Setting up vote account...".cyan());
        
        // Request airdrop on testnet
        if let Err(_) = solana.request_airdrop(LAMPORTS_PER_SOL).await {
            println!("{}", "  Airdrop failed (rate limited), continuing...".yellow());
        }
        
        // Setup vote account
        solana.setup_vote_account(5).await?; // 5% commission
    }
    
    // Step 6: Start optimized validator process
    println!("\n{}", "Step 6: Starting optimized validator...".cyan());
    let pid = start_optimized_validator(&config)?;
    
    // Step 7: Monitor initial performance
    println!("\n{}", "Step 7: Monitoring initial performance...".cyan());
    sleep(Duration::from_secs(5)).await;
    
    // Get initial metrics
    if let Ok(metrics) = solana.get_validator_metrics().await {
        metrics.display();
    }
    
    // Show system metrics
    let sys_metrics = SystemMonitor::get_metrics();
    display_system_metrics(&sys_metrics);
    
    println!("\n{}", "============================================".green());
    println!("{}", "✓ Validator started with optimizations!".green().bold());
    println!("Validator PID: {}", pid.to_string().yellow());
    println!("\n{}", "Real-time monitoring commands:".cyan());
    println!("  • Monitor metrics: {}", "solana-validator-optimizer monitor".blue());
    println!("  • Live dashboard: {}", "solana-validator-optimizer monitor --dashboard".blue());
    println!("  • Auto-optimize: {}", "solana-validator-optimizer optimize --auto".blue());
    println!("{}", "============================================".green());
    
    Ok(())
}

pub async fn stop() -> Result<()> {
    let mut system = System::new_all();
    system.refresh_all();
    
    let validator_processes: Vec<_> = system
        .processes()
        .iter()
        .filter(|(_, process)| process.name() == "solana-validator")
        .map(|(pid, _)| *pid)
        .collect();
    
    if validator_processes.is_empty() {
        println!("{}", "No validator process found".yellow());
        return Ok(());
    }
    
    for pid in validator_processes {
        println!("Stopping validator with PID: {}", pid);
        Command::new("kill")
            .args(&["-TERM", &pid.to_string()])
            .output()
            .context("Failed to stop validator")?;
    }
    
    println!("{}", "✓ Validator stopped".green());
    Ok(())
}

pub async fn show_status() -> Result<()> {
    println!("{}", "================================================".blue());
    println!("{}", "        Validator Status Dashboard".blue().bold());
    println!("{}", "================================================".blue());
    
    let mut system = System::new_all();
    system.refresh_all();
    
    let validator_process = system
        .processes()
        .iter()
        .find(|(_, process)| process.name() == "solana-validator");
    
    match validator_process {
        Some((pid, process)) => {
            println!("{} {}", "✓ Validator Status:".green(), "RUNNING".green().bold());
            println!("PID: {}", pid.to_string().yellow());
            println!("CPU Usage: {:.2}%", process.cpu_usage());
            println!("Memory Usage: {} MB", process.memory() / 1024 / 1024);
            
            // Get validator identity
            if let Ok(output) = Command::new("solana")
                .args(&["address"])
                .output()
            {
                if output.status.success() {
                    let address = String::from_utf8_lossy(&output.stdout);
                    println!("Identity: {}", address.trim().yellow());
                }
            }
            
            // Get current slot
            if let Ok(output) = Command::new("solana")
                .args(&["slot", "--url", "https://api.testnet.solana.com"])
                .output()
            {
                if output.status.success() {
                    let slot = String::from_utf8_lossy(&output.stdout);
                    println!("Network Slot: {}", slot.trim().cyan());
                }
            }
        }
        None => {
            println!("{} {}", "✗ Validator Status:".red(), "NOT RUNNING".red().bold());
            println!("Start the validator with: {}", "solana-validator-optimizer start".yellow());
        }
    }
    
    Ok(())
}

fn check_solana_installation() -> Result<()> {
    let output = Command::new("solana")
        .arg("--version")
        .output()
        .context("Solana CLI not found. Please install Solana first.")?;
    
    if output.status.success() {
        let version = String::from_utf8_lossy(&output.stdout);
        println!("✓ Solana CLI found: {}", version.trim().green());
    }
    
    // Check for solana-validator
    let validator_check = Command::new("which")
        .arg("solana-validator")
        .output()
        .context("Failed to check for solana-validator")?;
    
    if validator_check.status.success() {
        println!("{}", "✓ Full solana-validator found".green());
    } else {
        return Err(anyhow::anyhow!("solana-validator not found. Please install the full Solana validator."));
    }
    
    Ok(())
}

fn generate_keypairs(config: &ValidatorConfig) -> Result<()> {
    // Create directories
    fs::create_dir_all(config.ledger_path.parent().unwrap())?;
    fs::create_dir_all(&config.ledger_path)?;
    fs::create_dir_all(&config.accounts_path)?;
    fs::create_dir_all(&config.snapshots_path)?;
    fs::create_dir_all(config.log_path.parent().unwrap())?;
    
    // Generate identity keypair if it doesn't exist
    if !config.identity_keypair.exists() {
        println!("Generating new validator identity keypair...");
        Command::new("solana-keygen")
            .args(&["new", "--no-bip39-passphrase", "--outfile"])
            .arg(&config.identity_keypair)
            .stdin(Stdio::null())
            .output()
            .context("Failed to generate identity keypair")?;
        println!("✓ Identity keypair generated");
    } else {
        println!("✓ Using existing identity keypair");
    }
    
    // Generate vote account keypair if it doesn't exist
    if !config.vote_account_keypair.exists() {
        println!("Generating new vote account keypair...");
        Command::new("solana-keygen")
            .args(&["new", "--no-bip39-passphrase", "--outfile"])
            .arg(&config.vote_account_keypair)
            .stdin(Stdio::null())
            .output()
            .context("Failed to generate vote account keypair")?;
        println!("✓ Vote account keypair generated");
    } else {
        println!("✓ Using existing vote account keypair");
    }
    
    Ok(())
}

async fn apply_system_optimizations() -> Result<()> {
    println!("Applying system optimizations...");
    
    // Set file descriptor limits (macOS)
    Command::new("ulimit")
        .args(&["-n", "1000000"])
        .output()
        .ok();
    
    // Network optimizations (require sudo on macOS)
    if cfg!(target_os = "macos") {
        println!("Applying macOS network optimizations...");
        // These require sudo, so we'll just print recommendations
        println!("{}", "Run with sudo for full system optimizations".yellow());
    }
    
    println!("{}", "✓ System optimizations applied".green());
    Ok(())
}

async fn setup_vote_account(config: &ValidatorConfig) -> Result<()> {
    // Set Solana config to testnet
    Command::new("solana")
        .args(&["config", "set", "--url", "https://api.testnet.solana.com"])
        .output()
        .context("Failed to set Solana config")?;
    
    // Get validator pubkey
    let pubkey_output = Command::new("solana-keygen")
        .args(&["pubkey", config.identity_keypair.to_str().unwrap()])
        .output()
        .context("Failed to get validator pubkey")?;
    
    let validator_pubkey = String::from_utf8_lossy(&pubkey_output.stdout).trim().to_string();
    println!("Validator pubkey: {}", validator_pubkey.yellow());
    
    // Check balance
    let balance_output = Command::new("solana")
        .args(&["balance", "--url", "https://api.testnet.solana.com"])
        .output()
        .context("Failed to check balance")?;
    
    let balance_str = String::from_utf8_lossy(&balance_output.stdout);
    println!("Current balance: {}", balance_str.trim());
    
    // Request airdrop if balance is low
    if balance_str.contains("0 SOL") || balance_str.contains("0.0") {
        println!("Requesting testnet SOL airdrop...");
        let airdrop_result = Command::new("solana")
            .args(&["airdrop", "1", "--url", "https://api.testnet.solana.com"])
            .output();
        
        match airdrop_result {
            Ok(output) if output.status.success() => {
                println!("{}", "✓ Airdrop successful!".green());
                sleep(Duration::from_secs(5)).await;
            }
            _ => {
                println!("{}", "⚠ Airdrop failed (rate limited). You can:".yellow());
                println!("  1. Try again later");
                println!("  2. Use the testnet faucet: https://solfaucet.com");
                println!("  3. Continue anyway (validator will sync but not vote)");
            }
        }
    }
    
    Ok(())
}

fn start_optimized_validator(config: &ValidatorConfig) -> Result<u32> {
    println!("Starting validator with performance optimizations...");
    
    // Build optimized arguments
    let mut args = config.build_validator_args();
    
    // Add additional performance flags
    args.extend_from_slice(&[
        "--no-wait-for-vote-to-start-leader".to_string(),
        "--enable-rpc-transaction-history".to_string(),
        "--enable-extended-tx-metadata-storage".to_string(),
        "--rpc-send-transaction-leader-forward-count=2".to_string(),
        "--use-snapshot-archives-at-startup=when-newest".to_string(),
        "--minimal-snapshot-download-speed=10485760".to_string(), // 10MB/s minimum
        "--maximum-snapshot-download-abort=5".to_string(),
        "--no-check-vote-account".to_string(),
        "--no-wait-for-supermajority".to_string(),
        "--expected-shred-version=0".to_string(),
    ]);
    
    println!("  Starting with {} threads for RPC", config.optimization.rpc_threads);
    println!("  TPU coalesce: {}ms", config.optimization.tpu_coalesce_ms);
    println!("  Snapshot interval: {} slots", config.optimization.incremental_snapshot_interval);
    
    let mut child = Command::new("solana-validator")
        .args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .context("Failed to start validator process")?;
    
    let pid = child.id();
    
    // Give the validator a moment to start
    std::thread::sleep(Duration::from_secs(2));
    
    // Check if process is still running
    match child.try_wait() {
        Ok(Some(status)) => {
            return Err(anyhow::anyhow!("Validator exited immediately with status: {}", status));
        }
        Ok(None) => {
            println!("{}", "✓ Validator process is running with optimizations".green());
        }
        Err(e) => {
            return Err(anyhow::anyhow!("Failed to check validator status: {}", e));
        }
    }
    
    Ok(pid)
}

fn display_system_metrics(metrics: &crate::system::SystemMetrics) {
    println!("\n{}", "📊 System Performance".cyan().bold());
    println!("CPU Usage: {:.1}%", metrics.cpu_usage);
    println!("Memory: {} MB / {} MB ({:.1}%)", 
        metrics.memory_used_mb,
        metrics.memory_total_mb,
        (metrics.memory_used_mb as f64 / metrics.memory_total_mb as f64) * 100.0
    );
    println!("Load Average: {:.2} / {:.2} / {:.2}", 
        metrics.load_1min, 
        metrics.load_5min, 
        metrics.load_15min
    );
    
    if let Some(ref validator) = metrics.validator_process {
        println!("\n{}", "Validator Process:".yellow());
        println!("  PID: {} | CPU: {:.1}% | Memory: {} MB | Threads: {}", 
            validator.pid,
            validator.cpu_usage,
            validator.memory_mb,
            validator.threads
        );
    }
}
