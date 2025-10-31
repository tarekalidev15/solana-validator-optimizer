#!/bin/bash

# Create a simple test program for smart contract optimization testing
# This creates a basic Solana program that we can deploy and analyze

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}ℹ${NC}  $1"; }
success() { echo -e "${GREEN}✓${NC}  $1"; }
error() { echo -e "${RED}✗${NC}  $1"; }

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Creating Test Program for Optimization       ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ]; then
    error "Must be run from rust-port directory"
    exit 1
fi

TEST_PROGRAM_DIR="test-program"

info "Creating test program directory..."
mkdir -p "$TEST_PROGRAM_DIR/src"

# Create Cargo.toml for the test program
info "Creating Cargo.toml..."
cat > "$TEST_PROGRAM_DIR/Cargo.toml" <<'EOF'
[package]
name = "test-program"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "lib"]

[dependencies]
solana-program = "1.18"
borsh = "0.10"

[dev-dependencies]
solana-program-test = "1.18"
solana-sdk = "1.18"

[profile.release]
overflow-checks = true
lto = "fat"
codegen-units = 1

[profile.release.build-override]
opt-level = 3
incremental = false
codegen-units = 1
EOF

success "Cargo.toml created"

# Create a simple counter program
info "Creating test program source code..."
cat > "$TEST_PROGRAM_DIR/src/lib.rs" <<'EOF'
use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
};

// Define the program state
#[derive(BorshSerialize, BorshDeserialize, Debug)]
pub struct CounterAccount {
    pub count: u64,
}

// Declare the program entrypoint
entrypoint!(process_instruction);

// Program entrypoint implementation
pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    msg!("Counter program entrypoint");

    // Get the account that holds the counter
    let accounts_iter = &mut accounts.iter();
    let account = next_account_info(accounts_iter)?;

    // The account must be owned by the program
    if account.owner != program_id {
        msg!("Counter account does not have the correct program id");
        return Err(ProgramError::IncorrectProgramId);
    }

    // Parse instruction data (0 = increment, 1 = decrement, 2 = reset)
    let instruction = instruction_data.get(0).ok_or(ProgramError::InvalidInstructionData)?;

    // Deserialize the counter account
    let mut counter = CounterAccount::try_from_slice(&account.data.borrow())?;

    match instruction {
        0 => {
            // Increment
            counter.count = counter.count.checked_add(1).unwrap();
            msg!("Incremented counter to {}", counter.count);
        }
        1 => {
            // Decrement
            counter.count = counter.count.checked_sub(1).unwrap();
            msg!("Decremented counter to {}", counter.count);
        }
        2 => {
            // Reset
            counter.count = 0;
            msg!("Reset counter to 0");
        }
        _ => {
            msg!("Invalid instruction");
            return Err(ProgramError::InvalidInstructionData);
        }
    }

    // Serialize the updated counter back to the account
    counter.serialize(&mut &mut account.data.borrow_mut()[..])?;

    Ok(())
}
EOF

success "Test program source created"

# Build the program
info "Building test program..."
cd "$TEST_PROGRAM_DIR"

if cargo build-bpf 2>/dev/null || cargo build-sbf 2>/dev/null; then
    success "Test program built successfully"

    # Find the .so file
    if [ -f "target/deploy/test_program.so" ]; then
        SO_FILE="target/deploy/test_program.so"
    elif [ -f "target/sbf-solana-solana/release/test_program.so" ]; then
        SO_FILE="target/sbf-solana-solana/release/test_program.so"
    else
        warning "Could not find compiled .so file"
        info "You may need to build it manually with: cargo build-sbf"
        exit 0
    fi

    echo ""
    success "Test program ready for deployment!"
    echo ""
    echo -e "${CYAN}Program file:${NC} $SO_FILE"
    echo ""
    echo -e "${YELLOW}To deploy to local validator:${NC}"
    echo "  1. Start local validator: solana-test-validator"
    echo "  2. Deploy program: solana program deploy $SO_FILE"
    echo "  3. Use the program ID with the optimizer"
    echo ""
else
    warning "Could not build program (this requires Solana BPF/SBF toolchain)"
    info "To install:"
    echo "  sh -c \"\$(curl -sSfL https://release.solana.com/stable/install)\""
    echo "  cargo install --git https://github.com/solana-labs/cargo-build-sbf"
fi

cd ..
