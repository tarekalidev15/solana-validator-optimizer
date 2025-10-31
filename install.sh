#!/bin/bash

# Solana Validator Optimizer - Installation Script
# This script installs all required dependencies and packages

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "================================================"
echo "   Solana Validator Optimizer - Installer"
echo "================================================"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get OS type
get_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unsupported"
    fi
}

OS_TYPE=$(get_os)

if [ "$OS_TYPE" == "unsupported" ]; then
    echo -e "${RED}Error: Unsupported operating system${NC}"
    exit 1
fi

echo -e "${BLUE}Detected OS: $OS_TYPE${NC}"
echo ""

# Install system dependencies
install_system_deps() {
    echo -e "${BLUE}Installing system dependencies...${NC}"
    
    if [ "$OS_TYPE" == "macos" ]; then
        # Check if Homebrew is installed
        if ! command_exists brew; then
            echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Add Homebrew to PATH for ARM Macs
            if [ -f "/opt/homebrew/bin/brew" ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        fi
        
        # Install required packages
        echo -e "${BLUE}Installing packages via Homebrew...${NC}"
        # Clean up any problematic taps
        brew untap homebrew/homebrew-cask-fonts 2>/dev/null || true
        # Update Homebrew
        brew update 2>/dev/null || echo "Warning: Homebrew update failed, continuing..."
        # Install packages if not present
        for pkg in curl wget jq bc; do
            if ! brew list $pkg &>/dev/null; then
                echo "Installing $pkg..."
                brew install $pkg || echo "Warning: Failed to install $pkg"
            else
                echo "$pkg is already installed"
            fi
        done
        
    elif [ "$OS_TYPE" == "linux" ]; then
        # Update package manager
        if command_exists apt-get; then
            echo -e "${BLUE}Using apt-get...${NC}"
            sudo apt-get update
            sudo apt-get install -y curl wget jq bc build-essential pkg-config libssl-dev
        elif command_exists yum; then
            echo -e "${BLUE}Using yum...${NC}"
            sudo yum update -y
            sudo yum install -y curl wget jq bc gcc openssl-devel
        else
            echo -e "${YELLOW}Warning: Could not detect package manager${NC}"
        fi
    fi
}

# Install Rust if not present
install_rust() {
    if ! command_exists rustc; then
        echo -e "${BLUE}Installing Rust...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    else
        echo -e "${GREEN}✓ Rust is already installed${NC}"
        # Try to show version, but don't fail if there's a library issue
        rustc --version 2>/dev/null || echo "(Version check failed due to library issues, but Rust is installed)"
    fi
}

# Install Solana CLI tools
install_solana() {
    if ! command_exists solana; then
        echo -e "${BLUE}Installing Solana CLI tools...${NC}"
        sh -c "$(curl -sSfL https://release.solana.com/stable/install)"
        
        # Add to PATH
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        
        # Add to shell profile
        if [ -f "$HOME/.zshrc" ]; then
            echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> "$HOME/.zshrc"
        fi
        if [ -f "$HOME/.bashrc" ]; then
            echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> "$HOME/.bashrc"
        fi
    else
        echo -e "${GREEN}✓ Solana CLI is already installed${NC}"
        solana --version
    fi
}

# Check for Python (for potential future features)
check_python() {
    if command_exists python3; then
        echo -e "${GREEN}✓ Python3 is installed${NC}"
        python3 --version
    else
        echo -e "${YELLOW}⚠ Python3 not found (optional for advanced features)${NC}"
    fi
}

# Create validator directories
setup_directories() {
    echo -e "${BLUE}Setting up validator directories...${NC}"
    
    VALIDATOR_DIR="$HOME/solana-validator"
    mkdir -p "$VALIDATOR_DIR"/{ledger,accounts,snapshots,logs,keypairs}
    
    echo -e "${GREEN}✓ Directories created at $VALIDATOR_DIR${NC}"
}

# Set up system optimizations
setup_system_optimizations() {
    echo -e "${BLUE}Setting up system optimizations...${NC}"
    
    # Increase file descriptor limits for current session
    ulimit -n 65535 2>/dev/null || true
    
    if [ "$OS_TYPE" == "linux" ]; then
        # Create systemd service for persistent settings
        if [ "$EUID" -eq 0 ]; then
            # System-wide optimizations
            echo "fs.file-max = 1000000" >> /etc/sysctl.conf
            echo "* soft nofile 1000000" >> /etc/security/limits.conf
            echo "* hard nofile 1000000" >> /etc/security/limits.conf
            sysctl -p
        else
            echo -e "${YELLOW}Note: Run with sudo for system-level optimizations${NC}"
        fi
    elif [ "$OS_TYPE" == "macos" ]; then
        # macOS specific optimizations
        echo -e "${YELLOW}Note: macOS file descriptor limits may require system restart${NC}"
        sudo launchctl limit maxfiles 65536 200000 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ System optimizations configured${NC}"
}

# Make all scripts executable
make_scripts_executable() {
    echo -e "${BLUE}Making scripts executable...${NC}"
    chmod +x *.sh
    echo -e "${GREEN}✓ All scripts are now executable${NC}"
}

# Verify installation
verify_installation() {
    echo ""
    echo -e "${BLUE}Verifying installation...${NC}"
    echo ""
    
    local all_good=true
    
    # Check Solana CLI
    if command_exists solana; then
        echo -e "${GREEN}✓ Solana CLI:${NC} $(solana --version)"
    else
        echo -e "${RED}✗ Solana CLI not found${NC}"
        all_good=false
    fi
    
    # Check Solana Keygen
    if command_exists solana-keygen; then
        echo -e "${GREEN}✓ Solana Keygen:${NC} Found"
    else
        echo -e "${RED}✗ Solana Keygen not found${NC}"
        all_good=false
    fi
    
    # Check Solana Validator
    if command_exists solana-validator; then
        echo -e "${GREEN}✓ Solana Validator:${NC} Found"
    else
        echo -e "${RED}✗ Solana Validator not found${NC}"
        all_good=false
    fi
    
    # Check Python
    if command_exists python3; then
        echo -e "${GREEN}✓ Python3:${NC} $(python3 --version | cut -d' ' -f2)"
    else
        echo -e "${YELLOW}⚠ Python3 not found (optional)${NC}"
    fi
    
    # Check required tools
    for tool in curl wget jq bc; do
        if command_exists $tool; then
            echo -e "${GREEN}✓ $tool:${NC} Found"
        else
            echo -e "${RED}✗ $tool not found${NC}"
            all_good=false
        fi
    done
    
    echo ""
    if [ "$all_good" = true ]; then
        echo -e "${GREEN}✅ All required components are installed!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Some components are missing. Please check the errors above.${NC}"
        return 1
    fi
}

# Main installation flow
main() {
    echo -e "${BLUE}Starting installation process...${NC}"
    echo ""
    
    # Step 1: Install system dependencies
    echo -e "${BLUE}Step 1/7: Installing system dependencies${NC}"
    install_system_deps
    echo ""
    
    # Step 2: Install Rust
    echo -e "${BLUE}Step 2/7: Checking Rust installation${NC}"
    install_rust
    echo ""
    
    # Step 3: Install Solana
    echo -e "${BLUE}Step 3/7: Installing Solana CLI tools${NC}"
    install_solana
    echo ""
    
    # Step 4: Check for Python (optional)
    echo -e "${BLUE}Step 4/7: Checking optional dependencies${NC}"
    check_python
    echo ""
    
    # Step 5: Set up directories
    echo -e "${BLUE}Step 5/7: Setting up validator directories${NC}"
    setup_directories
    echo ""
    
    # Step 6: Configure system optimizations
    echo -e "${BLUE}Step 6/7: Configuring system optimizations${NC}"
    setup_system_optimizations
    echo ""
    
    # Step 7: Make scripts executable
    echo -e "${BLUE}Step 7/7: Setting script permissions${NC}"
    make_scripts_executable
    echo ""
    
    # Verify installation
    if verify_installation; then
        echo ""
        echo "================================================"
        echo -e "${GREEN}   Installation completed successfully!${NC}"
        echo "================================================"
        echo ""
        echo "Next steps:"
        echo "1. Run './run.sh' to start the validator optimizer"
        echo "2. The script will guide you through the setup process"
        echo ""
        echo -e "${YELLOW}Note: You may need to restart your terminal or run:${NC}"
        echo "  source ~/.bashrc  (or source ~/.zshrc)"
        echo "  to update your PATH with Solana tools"
        echo ""
    else
        echo ""
        echo "================================================"
        echo -e "${YELLOW}   Installation completed with warnings${NC}"
        echo "================================================"
        echo ""
        echo "Please address any missing components before running the validator."
        echo "You can re-run this installer after fixing issues."
        echo ""
        exit 1
    fi
}

# Check if running with required permissions
if [ "$OS_TYPE" == "linux" ] && [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Note: Running without sudo. Some system optimizations will be skipped.${NC}"
    echo -e "${YELLOW}For full optimization, consider running: sudo ./install.sh${NC}"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Run main installation
main
