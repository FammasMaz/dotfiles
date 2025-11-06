#!/bin/bash

# Linux Setup Script for dotfiles dependencies
# This script installs all the tools and dependencies used in the .zshrc and fish configurations

set -e  # Exit on any error

# Get the absolute path of the dotfiles directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Starting Linux setup for dotfiles dependencies..."

# Detect package manager
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
    UPDATE_CMD="sudo apt-get update"
    INSTALL_CMD="sudo apt-get install -y"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    UPDATE_CMD="sudo dnf check-update"
    INSTALL_CMD="sudo dnf install -y"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    UPDATE_CMD="sudo pacman -Syu"
    INSTALL_CMD="sudo pacman -S --noconfirm"
else
    echo "❌ Could not detect a supported package manager (apt, dnf, or pacman). Exiting."
    exit 1
fi

echo "🔄 Updating package list using $PKG_MANAGER..."
$UPDATE_CMD

echo "📦 Installing common dependencies..."
# List of packages for different distributions
declare -A packages
packages=(
    [apt-get]="bat eza duf zoxide thefuck gh zsh-autosuggestions zsh-syntax-highlighting fish"
    [dnf]="bat eza duf zoxide thefuck gh zsh-autosuggestions zsh-syntax-highlighting fish"
    [pacman]="bat eza duf zoxide thefuck gh zsh-autosuggestions zsh-syntax-highlighting fish"
)

# Install packages
for package in ${packages[$PKG_MANAGER]}; do
    if ! command -v "$package" &> /dev/null; then
        echo "📦 Installing $package..."
        $INSTALL_CMD "$package"
    else
        echo "✅ $package already installed"
    fi
done

# Install Starship prompt
if ! command -v starship &> /dev/null; then
    echo "📦 Installing Starship prompt..."
    mkdir -p "$HOME/.local/bin"
    curl -sS https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin"
    if [ -f "$HOME/.local/bin/starship" ]; then
        chmod +x "$HOME/.local/bin/starship"
    fi
    # Add to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"
fi

# Install GitHub Copilot CLI extension
echo "📦 Setting up GitHub Copilot CLI extension..."
if gh auth status &> /dev/null; then
    if gh extension list | grep -q "github/gh-copilot"; then
        echo "✅ GitHub Copilot CLI extension already installed"
    else
        echo "📦 Installing GitHub Copilot CLI extension..."
        gh extension install github/gh-copilot
    fi
else
    echo "⚠️  GitHub CLI not authenticated. Skipping GitHub Copilot CLI extension installation."
    echo "💡 After setup, run 'gh auth login' and then 'gh extension install github/gh-copilot'"
fi


# Install Miniconda3 if not already installed
if [ ! -d "$HOME/miniconda3" ]; then
    echo "📦 Installing Miniconda3..."
    
    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    
    # Download and install Miniconda
    curl -o ~/miniconda.sh "$MINICONDA_URL"
    bash ~/miniconda.sh -b -p "$HOME/miniconda3"
    rm ~/miniconda.sh
    
    # Initialize conda
    ~/miniconda3/bin/conda init zsh
    ~/miniconda3/bin/conda init fish
else
    echo "✅ Miniconda3 already installed"
fi

# Setup fish shell
echo "🐠 Setting up fish shell..."
./fishOS/fish/setup.sh

# Set up dotfiles symlink for easy access
if [ ! -L "$HOME/.dotfiles" ]; then
    ln -sf "$DOTFILES_DIR" "$HOME/.dotfiles"
    echo "✅ Created symlink to dotfiles directory at ~/.dotfiles"
fi

# Set up .zshrc symlink
ZDOT_PATH="$DOTFILES_DIR/macOS/.zshrc"
if [ -f "$ZDOT_PATH" ]; then
    echo "🔗 Setting up .zshrc symlink..."
    # Backup existing .zshrc if it exists
    if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
        mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
        echo "📋 Backed up existing .zshrc to .zshrc.backup"
    fi
    # Create symlink
    ln -sf "$ZDOT_PATH" "$HOME/.zshrc"
    echo "✅ .zshrc symlinked to $ZDOT_PATH"
else
    echo "❌ .zshrc not found at $ZDOT_PATH"
fi

echo "🎉 Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. Authenticate with GitHub CLI: gh auth login"
echo "3. Install GitHub Copilot CLI extension: gh extension install github/gh-copilot"
echo "4. GitHub Copilot CLI extension will be ready to use with 'gh copilot suggest'"
