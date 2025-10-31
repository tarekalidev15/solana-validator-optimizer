#!/bin/bash

# Script to install full Solana validator for testnet (not just test-validator)

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================================"
echo "   Installing Full Solana Validator for Testnet"
echo "================================================"
echo ""

# Solana version
SOLANA_VERSION="1.18.20"

echo -e "${BLUE}Installing Solana v$SOLANA_VERSION with full validator...${NC}"

# Remove any existing installation
if [ -d "$HOME/.local/share/solana" ]; then
    echo "Removing existing Solana installation..."
    rm -rf "$HOME/.local/share/solana"
fi

# Install full Solana release from source
echo -e "${BLUE}Downloading and installing Solana validator...${NC}"

# Try with wget first, fallback to curl
if command -v wget >/dev/null 2>&1; then
    wget -q -O - https://release.solana.com/v$SOLANA_VERSION/install | sh
elif command -v curl >/dev/null 2>&1; then
    curl -sSfL https://release.solana.com/v$SOLANA_VERSION/install | sh
else
    echo -e "${RED}Error: Neither wget nor curl found${NC}"
    exit 1
fi

# Add to PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Add to shell profiles
if ! grep -q ".local/share/solana" ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
fi

if ! grep -q ".local/share/solana" ~/.zshrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.zshrc
fi

# Verify installation
echo -e "\n${BLUE}Verifying installation...${NC}"

if [ -f "$HOME/.local/share/solana/install/active_release/bin/solana-validator" ]; then
    echo -e "${GREEN}✓ solana-validator installed successfully!${NC}"
    "$HOME/.local/share/solana/install/active_release/bin/solana-validator" --version
else
    echo -e "${YELLOW}Note: solana-validator not found in expected location${NC}"
    echo "Checking alternative installation methods..."
    
    # Alternative: Install via cargo if Rust is available
    if command -v cargo >/dev/null 2>&1; then
        echo -e "${BLUE}Installing solana-validator via cargo...${NC}"
        cargo install solana-validator --version $SOLANA_VERSION
    else
        echo -e "${RED}Error: Could not install solana-validator${NC}"
        echo "Please try one of these options:"
        echo "1. Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        echo "2. Build from source: https://docs.solana.com/cli/install-solana-cli-tools#build-from-source"
        exit 1
    fi
fi

echo -e "\n${GREEN}Installation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Restart your terminal or run: source ~/.bashrc (or ~/.zshrc)"
echo "2. Run: ./setup-validator.sh to start your testnet validator"
echo ""
echo -e "${YELLOW}Note: You'll need testnet SOL for voting. Use:${NC}"
echo "  ./request-airdrop.sh - for automated airdrop requests"
echo "  or visit: https://solfaucet.com"
