#!/bin/bash

# GitHub Push Helper Script
# Helps push the Solana Validator Optimizer to your GitHub repository

echo "============================================"
echo "   GitHub Repository Setup Helper"
echo "============================================"
echo ""

# Check if git is configured
if ! git config user.name > /dev/null 2>&1; then
    echo "Setting up git configuration..."
    read -p "Enter your name: " name
    read -p "Enter your email: " email
    git config user.name "$name"
    git config user.email "$email"
fi

echo "Current git configuration:"
echo "  Name: $(git config user.name)"
echo "  Email: $(git config user.email)"
echo ""

# Instructions for creating repo
echo "Step 1: Create a new repository on GitHub"
echo "  1. Go to https://github.com/new"
echo "  2. Name it: solana-validator-optimizer"
echo "  3. Make it public"
echo "  4. DON'T initialize with README (we already have one)"
echo "  5. Click 'Create repository'"
echo ""
echo "Press Enter when you've created the repository..."
read

# Get repository URL
echo "Step 2: Connect to your repository"
echo "Enter your GitHub username:"
read username
echo ""

# Add remote
REPO_URL="https://github.com/$username/solana-validator-optimizer.git"
echo "Adding remote repository: $REPO_URL"
git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"

# Push to GitHub
echo ""
echo "Step 3: Pushing to GitHub..."
echo "You may be prompted for your GitHub credentials."
echo ""

# Try to push
if git push -u origin master; then
    echo ""
    echo "✅ Success! Your repository is now available at:"
    echo "   https://github.com/$username/solana-validator-optimizer"
    echo ""
    echo "Share this link in your job interview!"
else
    echo ""
    echo "If push failed, you may need to:"
    echo "1. Create a Personal Access Token at: https://github.com/settings/tokens"
    echo "2. Use the token as your password when prompted"
    echo ""
    echo "Alternative: You can manually push using:"
    echo "  git remote add origin https://github.com/$username/solana-validator-optimizer.git"
    echo "  git push -u origin master"
fi

echo ""
echo "Repository contents:"
ls -la
echo ""
echo "Done!"
