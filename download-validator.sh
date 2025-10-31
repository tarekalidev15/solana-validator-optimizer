#!/bin/bash

# Direct download of Solana validator binaries for macOS

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "================================================"
echo "   Downloading Solana Validator Binaries"
echo "================================================"
echo ""

# Configuration
SOLANA_VERSION="v1.18.20"
INSTALL_DIR="$HOME/.local/share/solana/install/releases/$SOLANA_VERSION"
BIN_DIR="$INSTALL_DIR/bin"

# Create directories
mkdir -p "$BIN_DIR"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    PLATFORM="aarch64-apple-darwin"
elif [ "$ARCH" = "x86_64" ]; then
    PLATFORM="x86_64-apple-darwin"
else
    echo -e "${RED}Unsupported architecture: $ARCH${NC}"
    exit 1
fi

echo -e "${BLUE}Detected platform: $PLATFORM${NC}"

# GitHub release URL
RELEASE_URL="https://github.com/solana-labs/solana/releases/download/$SOLANA_VERSION"
ARCHIVE_NAME="solana-release-$PLATFORM.tar.bz2"
DOWNLOAD_URL="$RELEASE_URL/$ARCHIVE_NAME"

echo -e "${BLUE}Downloading from: $DOWNLOAD_URL${NC}"

# Download the release
cd /tmp
echo "Downloading Solana release..."
if command -v wget >/dev/null 2>&1; then
    wget --no-check-certificate "$DOWNLOAD_URL" -O "$ARCHIVE_NAME" || {
        echo -e "${YELLOW}Direct download failed, trying alternative method...${NC}"
        # Try with curl
        curl -L "$DOWNLOAD_URL" -o "$ARCHIVE_NAME"
    }
else
    curl -L "$DOWNLOAD_URL" -o "$ARCHIVE_NAME"
fi

# Extract the archive
echo -e "${BLUE}Extracting archive...${NC}"
tar -xjf "$ARCHIVE_NAME"

# Move binaries to installation directory
echo -e "${BLUE}Installing binaries...${NC}"
if [ -d "solana-release" ]; then
    mv solana-release/bin/* "$BIN_DIR/" 2>/dev/null || true
elif [ -d "bin" ]; then
    mv bin/* "$BIN_DIR/" 2>/dev/null || true
fi

# Create symlinks in active_release
ACTIVE_DIR="$HOME/.local/share/solana/install/active_release"
mkdir -p "$ACTIVE_DIR"
ln -sfn "$INSTALL_DIR/bin" "$ACTIVE_DIR/bin"

# Add to PATH
export PATH="$ACTIVE_DIR/bin:$PATH"

# Update shell profiles
if ! grep -q ".local/share/solana" ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
fi

if ! grep -q ".local/share/solana" ~/.zshrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.zshrc
fi

# Verify installation
echo -e "\n${BLUE}Verifying installation...${NC}"

if [ -f "$ACTIVE_DIR/bin/solana-validator" ]; then
    echo -e "${GREEN}✓ solana-validator installed successfully!${NC}"
    "$ACTIVE_DIR/bin/solana-validator" --version
    
    # Make all binaries executable
    chmod +x "$ACTIVE_DIR/bin/"*
    
    echo -e "\n${GREEN}Installation complete!${NC}"
    echo ""
    echo "Available tools:"
    ls -la "$ACTIVE_DIR/bin/" | grep solana | awk '{print "  - " $9}'
    echo ""
    echo "Next steps:"
    echo "1. Restart your terminal or run: source ~/.bashrc (or ~/.zshrc)"
    echo "2. Run: ./setup-validator.sh to start your testnet validator"
else
    echo -e "${RED}Error: solana-validator not found after extraction${NC}"
    echo "Archive contents:"
    ls -la /tmp/solana-release/ 2>/dev/null || ls -la /tmp/bin/ 2>/dev/null || echo "No extracted files found"
    exit 1
fi

# Cleanup
rm -f /tmp/"$ARCHIVE_NAME"
rm -rf /tmp/solana-release 2>/dev/null || true
