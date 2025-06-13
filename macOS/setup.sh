#!/bin/bash

# macOS Setup Script for .zshrc dependencies
# This script installs all the tools and dependencies used in the .zshrc configuration

set -e  # Exit on any error

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
    "oh-my-posh"    # Prompt theme engine
)

for package in "${brew_packages[@]}"; do
    if brew list "$package" &>/dev/null; then
        echo "✅ $package already installed"
    else
        echo "📦 Installing $package..."
        brew install "$package"
    fi
done

# Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "📦 Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "✅ Oh My Zsh already installed"
fi

# Install zsh-autosuggestions plugin
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    echo "📦 Installing zsh-autosuggestions plugin..."
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo "✅ zsh-autosuggestions already installed"
fi

# Install zsh-syntax-highlighting plugin
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    echo "📦 Installing zsh-syntax-highlighting plugin..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo "✅ zsh-syntax-highlighting already installed"
fi

# Install Miniconda3 if not already installed
if [ ! -d "$HOME/miniconda3" ]; then
    echo "📦 Installing Miniconda3..."
    
    # Detect architecture
    if [[ $(uname -m) == "arm64" ]]; then
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
    else
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
    fi
    
    # Download and install Miniconda
    curl -o ~/miniconda.sh "$MINICONDA_URL"
    bash ~/miniconda.sh -b -p "$HOME/miniconda3"
    rm ~/miniconda.sh
    
    # Initialize conda
    ~/miniconda3/bin/conda init zsh
else
    echo "✅ Miniconda3 already installed"
fi

# Setup GitHub CLI authentication (optional)
echo "🔐 Setting up GitHub CLI..."
echo "You may want to authenticate with GitHub CLI by running: gh auth login"

# Verify installations
echo "🔍 Verifying installations..."
commands_to_check=("bat" "eza" "duf" "zoxide" "thefuck" "gh" "oh-my-posh")

for cmd in "${commands_to_check[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        echo "✅ $cmd is available"
    else
        echo "❌ $cmd is not available"
    fi
done

echo "🎉 Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. Authenticate with GitHub CLI: gh auth login"
echo "3. If you want to enable GitHub Copilot CLI: gh extension install github/gh-copilot"
echo ""
echo "💡 Note: Some tools may require additional configuration:"
echo "   - Run 'thefuck --alias' to see fuck alias setup"
echo "   - Run 'zoxide --help' to learn about z command usage"
echo "   - The atomic.omp.json theme should be available at /opt/homebrew/opt/oh-my-posh/themes/"
