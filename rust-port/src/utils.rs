use anyhow::Result;
use colored::Colorize;
use std::process::Command;

pub fn format_sol(lamports: u64) -> String {
    let sol = lamports as f64 / 1_000_000_000.0;
    format!("{:.9} SOL", sol)
}

pub fn format_number(n: u64) -> String {
    let s = n.to_string();
    let mut result = String::new();
    for (i, c) in s.chars().rev().enumerate() {
        if i > 0 && i % 3 == 0 {
            result.insert(0, ',');
        }
        result.insert(0, c);
    }
    result
}

pub fn run_command(cmd: &str, args: &[&str]) -> Result<String> {
    let output = Command::new(cmd)
        .args(args)
        .output()?;
    
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

pub fn print_header(title: &str) {
    println!("{}", "=".repeat(60).blue());
    println!("{}", title.blue().bold());
    println!("{}", "=".repeat(60).blue());
}

pub fn print_success(message: &str) {
    println!("{} {}", "✓".green(), message.green());
}

pub fn print_warning(message: &str) {
    println!("{} {}", "⚠".yellow(), message.yellow());
}

pub fn print_error(message: &str) {
    println!("{} {}", "✗".red(), message.red());
}

pub fn print_info(message: &str) {
    println!("{} {}", "ℹ".cyan(), message.cyan());
}
