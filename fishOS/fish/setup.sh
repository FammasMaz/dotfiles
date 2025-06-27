#!/bin/bash

set -e  # Exit on any error

echo "🐠 Installing fish shell configuration..."

# Determine the absolute path of the dotfiles repository
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FISH_CONFIG_DIR="$DOTFILES_DIR/fishOS/fish"

echo "📁 Using dotfiles repository at: $DOTFILES_DIR"

# Function to detect OS and install fish
install_fish() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - use Homebrew
        echo "📦 Detected macOS, using Homebrew..."
        if ! command -v brew &> /dev/null; then
            echo "❌ Homebrew not found. Please install Homebrew first."
            exit 1
        fi
        
        if ! brew list fish &>/dev/null; then
            echo "📦 Installing fish..."
            brew install fish
        else
            echo "✅ fish already installed"
        fi
        
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux - detect package manager
        echo "📦 Detected Linux, determining package manager..."
        
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            echo "📦 Using apt-get..."
            sudo apt-get update
            if ! dpkg -l | grep -q "^ii  fish "; then
                echo "📦 Installing fish..."
                sudo apt-get install -y fish
            else
                echo "✅ fish already installed"
            fi
            
        elif command -v dnf &> /dev/null; then
            # Fedora
            echo "📦 Using dnf..."
            if ! dnf list installed fish &>/dev/null; then
                echo "📦 Installing fish..."
                sudo dnf install -y fish
            else
                echo "✅ fish already installed"
            fi
            
        elif command -v pacman &> /dev/null; then
            # Arch Linux
            echo "📦 Using pacman..."
            if ! pacman -Q fish &>/dev/null; then
                echo "📦 Installing fish..."
                sudo pacman -S --noconfirm fish
            else
                echo "✅ fish already installed"
            fi
            
        elif command -v zypper &> /dev/null; then
            # openSUSE
            echo "📦 Using zypper..."
            if ! zypper se -i fish &>/dev/null; then
                echo "📦 Installing fish..."
                sudo zypper install -y fish
            else
                echo "✅ fish already installed"
            fi
            
        else
            echo "❌ Could not detect a supported package manager"
            echo "Please install fish manually and run this script again"
            exit 1
        fi
        
    else
        echo "❌ Unsupported operating system: $OSTYPE"
        echo "Please install fish manually and run this script again"
        exit 1
    fi
}

# Install fish if not already installed
if ! command -v fish &> /dev/null; then
    install_fish
else
    echo "✅ fish already installed"
fi

# Verify fish installation
if ! command -v fish &> /dev/null; then
    echo "❌ fish installation failed or fish is not in PATH"
    exit 1
fi

# Create fish config directory if it doesn't exist
mkdir -p "$HOME/.config/fish"

# Install fisher (fish plugin manager)
if ! fish -c "type -q fisher" 2>/dev/null; then
    echo "📦 Installing fisher..."
    fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"
else
    echo "✅ fisher already installed"
fi

# Install plugins
echo "📦 Installing fish plugins..."
fish -c "fisher install jethrokuan/z" 2>/dev/null || echo "⚠️  z plugin installation failed or already installed"
fish -c "fisher install PatrickF1/fzf.fish" 2>/dev/null || echo "⚠️  fzf.fish plugin installation failed or already installed"

# Set up symlink to dotfiles directory for easy access
if [ ! -L "$HOME/.dotfiles" ]; then
    ln -sf "$DOTFILES_DIR" "$HOME/.dotfiles"
    echo "✅ Created symlink to dotfiles directory at ~/.dotfiles"
fi

# Symlink the config.fish file from the dotfiles repository
echo "🔗 Setting up fish configuration..."
if [ -f "$FISH_CONFIG_DIR/config.fish" ]; then
    ln -sf "$FISH_CONFIG_DIR/config.fish" "$HOME/.config/fish/config.fish"
    echo "✅ Linked config.fish from dotfiles repository"
else
    echo "❌ config.fish not found in $FISH_CONFIG_DIR"
    exit 1
fi

# Convert zsh history to fish if zsh_history exists
if [ -f "$HOME/.zsh_history" ]; then
    echo "📚 Converting zsh history to fish..."
    # Create fish history directory if it doesn't exist
    mkdir -p "$HOME/.local/share/fish"
    
    # Create a temporary directory for the conversion tool
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Clone the conversion tool
    git clone https://github.com/thenktor/zsh-history-to-fish.git
    cd zsh-history-to-fish
    
    # Empty the fish_history file and convert
    > "$HOME/.local/share/fish/fish_history"
    ./zsh-fish.sh -i "$HOME/.zsh_history" -o "$HOME/.local/share/fish/fish_history"
    
    # Clean up temporary directory
    cd /
    rm -rf "$TEMP_DIR"
else
    echo "ℹ️  No zsh history found to convert"
fi

echo "🎉 Fish shell setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. To use fish as your default shell, run:"
echo "   chsh -s \$(which fish)"
echo "2. Restart your terminal or run: fish"
echo "3. Your fish configuration is now active!"
echo ""
echo "📁 Configuration files are linked from: $FISH_CONFIG_DIR"
