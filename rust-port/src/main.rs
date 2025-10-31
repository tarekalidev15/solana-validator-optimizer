mod config;
mod monitor;
mod optimizer;
mod validator;
mod utils;
mod system;
mod blockchain;
mod process_manager;
mod real_optimizer;

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
    }

    Ok(())
}
