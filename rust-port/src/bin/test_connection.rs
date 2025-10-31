use anyhow::Result;
use solana_validator_optimizer_rs::blockchain::SolanaInterface;
use solana_sdk::signature::{Keypair, Signer};

#[tokio::main]
async fn main() -> Result<()> {
    println!("🧪 Testing Solana Interface Connection...");

    // Generate test keypairs
    let validator_keypair = Keypair::new();
    let vote_keypair = Keypair::new();

    println!("🔑 Generated keypairs:");
    println!("  Validator: {}", validator_keypair.pubkey());
    println!("  Vote: {}", vote_keypair.pubkey());

    // Try to connect to local validator
    println!("\n🌐 Testing connection to http://127.0.0.1:8899...");
    match SolanaInterface::new(
        "http://127.0.0.1:8899",
        validator_keypair,
        vote_keypair,
    ) {
        Ok(interface) => {
            println!("✅ Connected to local validator!");
            match interface.get_validator_metrics().await {
                Ok(metrics) => {
                    println!("📊 Got metrics:");
                    println!("  Vote Success: {:.1}%", metrics.vote_success_rate);
                    println!("  Skip Rate: {:.1}%", metrics.skip_rate);
                    println!("  Credits: {}", metrics.credits_earned);
                }
                Err(e) => {
                    println!("⚠️  Could not get metrics: {}", e);
                    println!("  This is expected if validator is not fully synced");
                }
            }
        }
        Err(e) => {
            println!("❌ Failed to connect to local: {}", e);

            // Try testnet with new keypairs
            println!("\n🌐 Testing connection to https://api.testnet.solana.com...");
            let validator_keypair = Keypair::new();
            let vote_keypair = Keypair::new();
            match SolanaInterface::new(
                "https://api.testnet.solana.com",
                validator_keypair,
                vote_keypair,
            ) {
                Ok(interface) => {
                    println!("✅ Connected to testnet!");
                    match interface.get_validator_metrics().await {
                        Ok(metrics) => {
                            println!("📊 Got metrics from testnet:");
                            println!("  Vote Success: {:.1}%", metrics.vote_success_rate);
                            println!("  Skip Rate: {:.1}%", metrics.skip_rate);
                            println!("  Credits: {}", metrics.credits_earned);
                        }
                        Err(e) => {
                            println!("⚠️  Could not get metrics from testnet: {}", e);
                        }
                    }
                }
                Err(e) => {
                    println!("❌ Failed to connect to testnet: {}", e);
                }
            }
        }
    }

    println!("\n✅ Test complete!");
    Ok(())
}
