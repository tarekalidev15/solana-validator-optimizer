mod config;
mod monitor;
mod optimizer;
mod validator;
mod utils;
mod system;
mod blockchain;
mod process_manager;
mod real_optimizer;
mod smart_contract;

use anyhow::Result;
use clap::{Parser, Subcommand};
use colored::Colorize;

#[derive(Parser)]
#[command(name = "solana-validator-optimizer")]
#[command(author = "Tarek Ali")]
#[command(version = "1.0")]
#[command(about = "Solana Validator Optimizer - Maximizing Vote Success Rate", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the validator with optimizations
    Start {
        /// Skip airdrop request
        #[arg(long)]
        no_airdrop: bool,
    },
    /// Stop the running validator
    Stop,
    /// Monitor validator performance
    Monitor {
        /// Use dashboard view
        #[arg(long)]
        dashboard: bool,
    },
    /// Apply optimizations to running validator
    Optimize {
        /// Auto-tune continuously
        #[arg(long)]
        auto: bool,
    },
    /// Generate performance report
    Report,
    /// Show validator status
    Status,
    /// Analyze smart contract performance
    AnalyzeContract {
        /// Program ID to analyze
        program_id: String,
        /// RPC URL (defaults to testnet)
        #[arg(long, default_value = "https://api.testnet.solana.com")]
        rpc_url: String,
    },
    /// Optimize smart contract
    OptimizeContract {
        /// Program ID to optimize
        program_id: String,
        /// RPC URL (defaults to testnet)
        #[arg(long, default_value = "https://api.testnet.solana.com")]
        rpc_url: String,
    },
    /// Monitor smart contract in real-time
    MonitorContract {
        /// Program ID to monitor
        program_id: String,
        /// RPC URL (defaults to testnet)
        #[arg(long, default_value = "https://api.testnet.solana.com")]
        rpc_url: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Start { no_airdrop } => {
            println!("{}", "Starting Solana Validator with Optimizations...".green().bold());
            validator::start(no_airdrop).await?;
        }
        Commands::Stop => {
            println!("{}", "Stopping Solana Validator...".yellow());
            validator::stop().await?;
        }
        Commands::Monitor { dashboard } => {
            if dashboard {
                println!("{}", "Launching Performance Dashboard...".blue().bold());
                monitor::dashboard().await?;
            } else {
                monitor::display_metrics().await?;
            }
        }
        Commands::Optimize { auto } => {
            println!("{}", "Running Optimizer...".cyan().bold());
            optimizer::run(auto).await?;
        }
        Commands::Report => {
            println!("{}", "Generating Performance Report...".magenta());
            monitor::generate_report().await?;
        }
        Commands::Status => {
            validator::show_status().await?;
        }
        Commands::AnalyzeContract { program_id, rpc_url } => {
            println!("{}", "Analyzing Smart Contract...".cyan().bold());
            analyze_smart_contract(&program_id, &rpc_url).await?;
        }
        Commands::OptimizeContract { program_id, rpc_url } => {
            println!("{}", "Optimizing Smart Contract...".green().bold());
            optimize_smart_contract(&program_id, &rpc_url).await?;
        }
        Commands::MonitorContract { program_id, rpc_url } => {
            println!("{}", "Monitoring Smart Contract...".blue().bold());
            monitor_smart_contract(&program_id, &rpc_url).await?;
        }
    }

    Ok(())
}

async fn analyze_smart_contract(program_id_str: &str, rpc_url: &str) -> Result<()> {
    use solana_sdk::pubkey::Pubkey;
    use std::str::FromStr;

    let program_id = Pubkey::from_str(program_id_str)
        .map_err(|e| anyhow::anyhow!("Invalid program ID: {}", e))?;

    let optimizer = smart_contract::SmartContractOptimizer::new(rpc_url, Some(program_id))?;

    let metrics = optimizer.analyze_program(&program_id).await?;
    optimizer.display_metrics(&metrics);

    let recommendations = optimizer.get_recommendations(&metrics);
    optimizer.display_recommendations(&recommendations);

    Ok(())
}

async fn optimize_smart_contract(program_id_str: &str, rpc_url: &str) -> Result<()> {
    use solana_sdk::pubkey::Pubkey;
    use std::str::FromStr;

    let program_id = Pubkey::from_str(program_id_str)
        .map_err(|e| anyhow::anyhow!("Invalid program ID: {}", e))?;

    let optimizer = smart_contract::SmartContractOptimizer::new(rpc_url, Some(program_id))?;

    // First analyze
    let metrics = optimizer.analyze_program(&program_id).await?;
    optimizer.display_metrics(&metrics);

    // Show recommendations
    let recommendations = optimizer.get_recommendations(&metrics);
    optimizer.display_recommendations(&recommendations);

    // Apply optimizations
    optimizer.apply_optimizations(&program_id).await?;

    println!("\n{}", "✅ Smart contract optimization complete!".green().bold());
    println!("Re-run 'analyze-contract' to see the improvements.");

    Ok(())
}

async fn monitor_smart_contract(program_id_str: &str, rpc_url: &str) -> Result<()> {
    use solana_sdk::pubkey::Pubkey;
    use std::str::FromStr;

    let program_id = Pubkey::from_str(program_id_str)
        .map_err(|e| anyhow::anyhow!("Invalid program ID: {}", e))?;

    let optimizer = smart_contract::SmartContractOptimizer::new(rpc_url, Some(program_id))?;
    optimizer.monitor_program(&program_id).await?;

    Ok(())
}
