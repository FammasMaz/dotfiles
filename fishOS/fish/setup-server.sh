#!/bin/bash

set -e  # Exit on any error

echo "🐠 Installing fish shell configuration for server (no sudo)..."

# Determine the absolute path of the dotfiles repository
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FISH_CONFIG_DIR="$DOTFILES_DIR/fishOS/fish"

echo "📁 Using dotfiles repository at: $DOTFILES_DIR"

# Create local directories
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share"
mkdir -p "$HOME/.config/fish"

# Function to install bat from source
install_bat() {
    if [ -f "$HOME/.local/bin/bat" ]; then
        echo "✅ bat already installed locally"
        return
    fi
    
    echo "📦 Installing bat from source..."
    
    # Check if rust is available
    if ! command -v cargo &> /dev/null; then
        echo "📦 Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    git clone https://github.com/sharkdp/bat.git
    cd bat
    cargo build --release
    cp target/release/bat "$HOME/.local/bin/"
    
    cd /
    rm -rf "$TEMP_DIR"
    echo "✅ bat installed"
}

# Function to install eza from source
install_eza() {
    if [ -f "$HOME/.local/bin/eza" ]; then
        echo "✅ eza already installed locally"
        return
    fi
    
    echo "📦 Installing eza from source..."
    
    # Check if rust is available
    if ! command -v cargo &> /dev/null; then
        echo "📦 Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    git clone https://github.com/eza-community/eza.git
    cd eza
    cargo build --release
    cp target/release/eza "$HOME/.local/bin/"
    
    cd /
    rm -rf "$TEMP_DIR"
    echo "✅ eza installed"
}

# Function to install oh-my-posh
install_oh_my_posh() {
    if [ -f "$HOME/.local/bin/oh-my-posh" ]; then
        echo "✅ oh-my-posh already installed locally"
        return
    fi
    
    echo "📦 Installing oh-my-posh..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; return ;;
    esac
    
    # Download and install
    curl -L "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-$ARCH" -o "$HOME/.local/bin/oh-my-posh"
    chmod +x "$HOME/.local/bin/oh-my-posh"
    echo "✅ oh-my-posh installed"
}

# Function to install zoxide
install_zoxide() {
    if [ -f "$HOME/.local/bin/zoxide" ]; then
        echo "✅ zoxide already installed locally"
        return
    fi
    
    echo "📦 Installing zoxide..."
    
    # Check if rust is available
    if ! command -v cargo &> /dev/null; then
        echo "📦 Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    cargo install zoxide --root "$HOME/.local"
    echo "✅ zoxide installed"
}

# Function to install duf
install_duf() {
    if [ -f "$HOME/.local/bin/duf" ]; then
        echo "✅ duf already installed locally"
        return
    fi
    
    echo "📦 Installing duf..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="x86_64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; return ;;
    esac
    
    # Get latest version
    LATEST=$(curl -s https://api.github.com/repos/muesli/duf/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
    
    # Download and install
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    curl -L "https://github.com/muesli/duf/releases/download/v$LATEST/duf_${LATEST}_linux_${ARCH}.tar.gz" -o duf.tar.gz
    tar -xzf duf.tar.gz
    cp duf "$HOME/.local/bin/"
    
    cd /
    rm -rf "$TEMP_DIR"
    echo "✅ duf installed"
}

# Function to install fish from source
install_fish_from_source() {
    echo "📦 Installing fish from source to ~/.local/..."
    
    # Create temporary directory for building
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download fish source
    FISH_VERSION="3.7.1"
    echo "📥 Downloading fish $FISH_VERSION..."
    curl -L "https://github.com/fish-shell/fish-shell/releases/download/$FISH_VERSION/fish-$FISH_VERSION.tar.xz" -o fish.tar.xz
    tar -xf fish.tar.xz
    cd "fish-$FISH_VERSION"
    
    # Build and install fish
    echo "🔨 Building fish..."
    cmake -DCMAKE_INSTALL_PREFIX="$HOME/.local" .
    make -j$(nproc 2>/dev/null || echo 4)
    make install
    
    # Clean up
    cd /
    rm -rf "$TEMP_DIR"
    
    echo "✅ Fish installed to ~/.local/bin/fish"
}

# Check if fish is already installed locally
if [ -f "$HOME/.local/bin/fish" ]; then
    echo "✅ fish already installed locally"
else
    # Check if we have required build tools
    if ! command -v cmake &> /dev/null || ! command -v make &> /dev/null || ! command -v gcc &> /dev/null; then
        echo "❌ Required build tools not found (cmake, make, gcc)"
        echo "Please ask your system administrator to install: cmake make gcc g++"
        exit 1
    fi
    
    install_fish_from_source
fi

# Update PATH to include local bin and cargo
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Install enhanced tools
echo "🔧 Installing enhanced tools locally..."
install_bat
install_eza
install_oh_my_posh
install_zoxide
install_duf

# Verify fish installation
if ! command -v fish &> /dev/null; then
    echo "❌ fish installation failed or fish is not in PATH"
    echo "Make sure ~/.local/bin is in your PATH"
    exit 1
fi

# Install fisher (fish plugin manager)
if ! "$HOME/.local/bin/fish" -c "type -q fisher" 2>/dev/null; then
    echo "📦 Installing fisher..."
    "$HOME/.local/bin/fish" -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"
else
    echo "✅ fisher already installed"
fi

# Install plugins
echo "📦 Installing fish plugins..."
"$HOME/.local/bin/fish" -c "fisher install jethrokuan/z" 2>/dev/null || echo "⚠️  z plugin installation failed or already installed"
"$HOME/.local/bin/fish" -c "fisher install PatrickF1/fzf.fish" 2>/dev/null || echo "⚠️  fzf.fish plugin installation failed or already installed"

# Set up symlink to dotfiles directory for easy access
if [ ! -L "$HOME/.dotfiles" ]; then
    ln -sf "$DOTFILES_DIR" "$HOME/.dotfiles"
    echo "✅ Created symlink to dotfiles directory at ~/.dotfiles"
fi

# Create server-specific config.fish
echo "🔗 Setting up fish configuration for server..."
cat > "$HOME/.config/fish/config.fish" << 'EOF'
# History settings
set -U fish_history_size 10000

# General options
set -g fish_greeting ""

# Environment variables - Server specific paths
set -x PATH "$HOME/.local/bin" "$HOME/.cargo/bin" $PATH

# Aliases
alias cat='bat'
alias lsa='eza -al --icons=always --color=always --sort=date'
alias df='duf'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias cd='z'

# Zoxide
zoxide init fish | source

# Oh My Posh
if test -f "$HOME/.dotfiles/themes/atomic.omp.json"
    oh-my-posh init fish --config "$HOME/.dotfiles/themes/atomic.omp.json" | source
end

# Conda (only if available)
if test -f "$HOME/miniconda3/bin/conda"
    eval "$HOME/miniconda3/bin/conda" "shell.fish" "hook" $argv | source
else
    if test -f "$HOME/miniconda3/etc/fish/conf.d/conda.fish"
        . "$HOME/miniconda3/etc/fish/conf.d/conda.fish"
    else
        if test -d "$HOME/miniconda3/bin"
            set -x PATH "$HOME/miniconda3/bin" $PATH
        end
    end
end
EOF

echo "✅ Created server-specific fish configuration"

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

echo "🎉 Fish shell server setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Add ~/.local/bin and ~/.cargo/bin to your PATH in ~/.bashrc or ~/.profile:"
echo "   echo 'export PATH=\"\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH\"' >> ~/.bashrc"
echo "2. To use fish as your default shell (if allowed), run:"
echo "   chsh -s \$HOME/.local/bin/fish"
echo "3. Or simply start fish manually: ~/.local/bin/fish"
echo ""
echo "📁 Fish binary: $HOME/.local/bin/fish"
echo "📁 Configuration: $HOME/.config/fish/config.fish"
echo "📁 Enhanced tools: ~/.local/bin/{bat,eza,oh-my-posh,zoxide,duf}"
echo "📁 Dotfiles link: $HOME/.dotfiles"