#!/bin/bash

# macOS Setup Script for .zshrc dependencies
# This script installs all the tools and dependencies used in the .zshrc configuration

set -e  # Exit on any error

# Get the absolute path of the dotfiles directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Starting macOS setup for .zshrc dependencies..."

# Check if Homebrew is installed, install if not
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew already installed"
fi

# Update Homebrew
echo "🔄 Updating Homebrew..."
brew update

# Install command-line tools via Homebrew
echo "📦 Installing command-line tools..."
brew_packages=(
    "bat"           # Modern cat replacement
    "eza"           # Modern ls replacement
    "duf"           # Modern df replacement
    "zoxide"        # Smart cd command
    "thefuck"       # Command correction tool
    "gh"            # GitHub CLI
    "atuin"
    "fzf" # Shell history sync tool
)

for package in "${brew_packages[@]}"; do
    if brew list "$package" &>/dev/null; then
        echo "✅ $package already installed"
    else
        echo "📦 Installing $package..."
        brew install "$package"
    fi
done

# Note: Oh My Zsh is no longer used - we use brew-installed plugins directly

# Install zsh plugins via Homebrew
echo "📦 Installing zsh plugins..."
zsh_plugins=(
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
)

for plugin in "${zsh_plugins[@]}"; do
    if brew list "$plugin" &>/dev/null; then
        echo "✅ $plugin already installed"
    else
        echo "📦 Installing $plugin..."
        brew install "$plugin"
    fi
done

# Install uv for Python package management
if ! command -v uv &> /dev/null; then
    echo "📦 Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo "✅ uv already installed"
fi

# Install GitHub Copilot CLI extension
echo "📦 Installing GitHub Copilot CLI extension..."
if gh extension list | grep -q "github/gh-copilot"; then
    echo "✅ GitHub Copilot CLI extension already installed"
else
    echo "📦 Installing GitHub Copilot CLI extension..."
    gh extension install github/gh-copilot
fi

# Setup GitHub CLI authentication (optional)
echo "🔐 Setting up GitHub CLI..."
echo "You may want to authenticate with GitHub CLI by running: gh auth login"

# Verify installations
echo "🔍 Verifying installations..."
commands_to_check=("bat" "eza" "duf" "zoxide" "thefuck" "gh" "atuin" "uv")

for cmd in "${commands_to_check[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        echo "✅ $cmd is available"
    else
        echo "❌ $cmd is not available"
    fi
done

# Check GitHub Copilot CLI extension
if gh extension list | grep -q "github/gh-copilot"; then
    echo "✅ GitHub Copilot CLI extension is available"
else
    echo "❌ GitHub Copilot CLI extension is not available"
fi

echo "🎉 Setup complete!"
echo ""

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

echo "📋 Next steps:"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. Authenticate with GitHub CLI: gh auth login"
echo "3. GitHub Copilot CLI extension is now installed and ready to use with 'gh copilot suggest'"
echo "4. Create Python projects with uv: uv init my-project"
echo ""
echo "💡 Note: Some tools may require additional configuration:"
echo "   - Run 'thefuck --alias' to see fuck alias setup"
echo "   - Run 'zoxide --help' to learn about z command usage"
echo "   - Run 'uv --help' to learn about Python package management with uv"
