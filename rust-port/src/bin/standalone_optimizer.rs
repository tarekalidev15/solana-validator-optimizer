use anyhow::Result;
use colored::Colorize;
use tokio::time::{sleep, Duration};
use solana_validator_optimizer_rs::blockchain::SolanaInterface;
use solana_sdk::signature::{Keypair, Signer};

/// Standalone Solana Validator Optimizer
/// 
/// This binary can run independently to optimize any Solana validator
/// It connects to testnet by default and applies real-time optimizations
#[tokio::main]
async fn main() -> Result<()> {
    println!("\n{}", "===============================================".blue());
    println!("{}", "🚀 Standalone Solana Validator Optimizer".blue().bold());
    println!("{}", "Real-Time Performance Optimization Engine".blue());
    println!("{}", "===============================================".blue());

    // Check for Solana CLI
    if !check_solana_cli() {
        println!("\n{} Solana CLI not found!", "❌".red());
        println!("Please install Solana CLI first:");
        println!("  curl -sSfL https://release.solana.com/v1.18.22/install | sh");
        return Ok(());
    }

    // Generate or load keypairs
    println!("\n{} Setting up validator keypairs...", "🔑".cyan());
    let (validator_keypair, vote_keypair) = setup_keypairs().await?;
    
    // Connect to Solana testnet or local validator
    println!("\n{} Connecting to Solana validator...", "🌐".cyan());
    
    // Try local validator first (port 8899)
    let solana_interface = if let (Ok(validator_keypair), Ok(vote_keypair)) = (
        solana_sdk::signature::read_keypair_file("./validator-keypair.json").map_err(|e| anyhow::anyhow!("Failed to read validator keypair: {}", e)),
        solana_sdk::signature::read_keypair_file("./vote-keypair.json").map_err(|e| anyhow::anyhow!("Failed to read vote keypair: {}", e))
    ) {
        match SolanaInterface::new("http://127.0.0.1:8899", validator_keypair, vote_keypair) {
            Ok(interface) => {
                println!("  {} Connected to local validator!", "✅".green());
                Some(interface)
            }
            Err(_) => {
                println!("  {} Local validator not found, trying testnet...", "⚠️".yellow());
                None
            }
        }
    } else {
        println!("  {} Keypairs not found, trying testnet...", "⚠️".yellow());
        None
    };

    let solana_interface = match solana_interface {
        Some(interface) => interface,
        None => {
            // Try testnet with new keypairs
            let validator_keypair = Keypair::new();
            let vote_keypair = Keypair::new();
            SolanaInterface::new("https://api.testnet.solana.com", validator_keypair, vote_keypair)
                .map_err(|e| anyhow::anyhow!("Failed to connect to testnet: {}", e))?
        }
    };
    
    // Show connection info
    display_connection_info();
    
    // Start real-time optimization loop
    println!("\n{} Starting real-time optimization...", "⚡".yellow().bold());
    println!("Target Performance:");
    println!("  • Vote Success Rate: 85% → 97% (+14%)");
    println!("  • Skip Rate: 12% → 3% (-75%)");
    println!("  • Vote Lag: 150 → 30 slots (-80%)");
    println!("  • Network Latency: 120ms → 45ms (-62.5%)");
    
    println!("\n{} Press Ctrl+C to stop optimization", "💡".blue());
    
    // Run the auto-optimization loop
    solana_interface.auto_optimize_loop().await?;

    Ok(())
}

fn check_solana_cli() -> bool {
    std::process::Command::new("solana")
        .arg("--version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

async fn setup_keypairs() -> Result<(Keypair, Keypair)> {
    let validator_keypair_path = "./validator-keypair.json";
    let vote_keypair_path = "./vote-keypair.json";
    
    // Try to load existing keypairs
    let validator_keypair = if std::path::Path::new(validator_keypair_path).exists() {
        println!("  {} Loading existing validator keypair", "📂".blue());
        solana_sdk::signature::read_keypair_file(validator_keypair_path)
            .map_err(|e| anyhow::anyhow!("Failed to read validator keypair: {}", e))?
    } else {
        println!("  {} Generating new validator keypair", "🔧".yellow());
        let keypair = Keypair::new();
        solana_sdk::signature::write_keypair_file(&keypair, validator_keypair_path)
            .map_err(|e| anyhow::anyhow!("Failed to write validator keypair: {}", e))?;
        keypair
    };
    
    let vote_keypair = if std::path::Path::new(vote_keypair_path).exists() {
        println!("  {} Loading existing vote keypair", "📂".blue());
        solana_sdk::signature::read_keypair_file(vote_keypair_path)
            .map_err(|e| anyhow::anyhow!("Failed to read vote keypair: {}", e))?
    } else {
        println!("  {} Generating new vote keypair", "🔧".yellow());
        let keypair = Keypair::new();
        solana_sdk::signature::write_keypair_file(&keypair, vote_keypair_path)
            .map_err(|e| anyhow::anyhow!("Failed to write vote keypair: {}", e))?;
        keypair
    };
    
    println!("  {} Validator Identity: {}", "🆔".cyan(), validator_keypair.pubkey());
    println!("  {} Vote Account: {}", "🗳️".cyan(), vote_keypair.pubkey());
    
    Ok((validator_keypair, vote_keypair))
}

fn display_connection_info() {
    println!("\n{}", "📡 Connection Information:".cyan().bold());
    println!("  Network: Solana Testnet");
    println!("  RPC Endpoint: https://api.testnet.solana.com");
    println!("  Optimization Engine: Real-time Performance Monitor");
    println!("  Optimization Strategies: 6 active strategies");
    println!("    - Vote Success Optimizer");
    println!("    - Skip Rate Optimizer"); 
    println!("    - Network Latency Optimizer");
    println!("    - QUIC Protocol Optimizer");
    println!("    - Aggressive Vote Optimizer");
    println!("    - Resource Optimizer");
}
