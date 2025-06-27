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

# Function to install bat
install_bat() {
    if [ -f "$HOME/.local/bin/bat" ]; then
        echo "✅ bat already installed locally"
        return
    fi
    
    echo "📦 Installing bat..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="x86_64" ;;
        aarch64) ARCH="aarch64" ;;
        armv7l) ARCH="arm" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; return ;;
    esac
    
    # Get latest version
    LATEST=$(curl -s https://api.github.com/repos/sharkdp/bat/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
    
    # Download and install
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    curl -L "https://github.com/sharkdp/bat/releases/download/v$LATEST/bat-v${LATEST}-${ARCH}-unknown-linux-musl.tar.gz" -o bat.tar.gz
    tar -xzf bat.tar.gz
    cp "bat-v${LATEST}-${ARCH}-unknown-linux-musl/bat" "$HOME/.local/bin/"
    
    cd /
    rm -rf "$TEMP_DIR"
    echo "✅ bat installed"
}

# Function to install eza
install_eza() {
    if [ -f "$HOME/.local/bin/eza" ]; then
        echo "✅ eza already installed locally"
        return
    fi
    
    echo "📦 Installing eza..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="x86_64" ;;
        aarch64) ARCH="aarch64" ;;
        armv7l) ARCH="armv7" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; return ;;
    esac
    
    # Get latest version
    LATEST=$(curl -s https://api.github.com/repos/eza-community/eza/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
    
    # Download and install
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    curl -L "https://github.com/eza-community/eza/releases/download/v$LATEST/eza_${ARCH}-unknown-linux-musl.tar.gz" -o eza.tar.gz
    tar -xzf eza.tar.gz
    cp eza "$HOME/.local/bin/"
    
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
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="x86_64" ;;
        aarch64) ARCH="aarch64" ;;
        armv7l) ARCH="armv7" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; return ;;
    esac
    
    # Get latest version
    LATEST=$(curl -s https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
    
    # Download and install
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    curl -L "https://github.com/ajeetdsouza/zoxide/releases/download/v$LATEST/zoxide-$LATEST-$ARCH-unknown-linux-musl.tar.gz" -o zoxide.tar.gz
    tar -xzf zoxide.tar.gz
    cp zoxide "$HOME/.local/bin/"
    
    cd /
    rm -rf "$TEMP_DIR"
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

# Function to install fish binary
install_fish_binary() {
    echo "📦 Installing fish binary to ~/.local/..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) STATIC_ARCH="amd64" ;;
        aarch64) STATIC_ARCH="aarch64" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; return 1 ;;
    esac
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download fish static binary
    FISH_VERSION="4.0.2"
    echo "📥 Downloading fish $FISH_VERSION static binary..."
    
    # Try static binary archive (these are tar.xz files with the static builds)
    echo "📥 Trying static build: fish-static-$STATIC_ARCH-$FISH_VERSION.tar.xz"
    curl -L "https://github.com/fish-shell/fish-shell/releases/download/$FISH_VERSION/fish-static-$STATIC_ARCH-$FISH_VERSION.tar.xz" -o fish-static.tar.xz
    
    if [ $? -eq 0 ] && [ -s fish-static.tar.xz ] && [ $(wc -c < fish-static.tar.xz) -gt 1000 ]; then
        echo "📦 Extracting static fish binary..."
        tar -xf fish-static.tar.xz
        
        # Find the fish binary in the extracted static build
        FISH_BIN=$(find . -name "fish" -type f -executable | head -1)
        if [ -n "$FISH_BIN" ]; then
            echo "📦 Found static fish binary at: $FISH_BIN"
            cp "$FISH_BIN" "$HOME/.local/bin/"
            
            # Copy fish data files if they exist
            mkdir -p "$HOME/.local/share/fish"
            FISH_SHARE=$(find . -path "*/share/fish" -type d | head -1)
            if [ -n "$FISH_SHARE" ]; then
                echo "📦 Found fish data at: $FISH_SHARE"
                cp -r "$FISH_SHARE"/* "$HOME/.local/share/fish/" 2>/dev/null || true
            fi
            # Clean up and return success
            cd /
            rm -rf "$TEMP_DIR"
            return 0
        else
            echo "❌ Could not find fish binary in static archive"
            echo "📋 Static archive contents:"
            find . -type f | head -10
        fi
    fi
    
    # If we get here, static binary failed, try source archive
    echo "❌ Static binary installation failed, trying source archive..."
    # Try downloading and building from source archive
    curl -L "https://github.com/fish-shell/fish-shell/releases/download/$FISH_VERSION/fish-$FISH_VERSION.tar.xz" -o fish.tar.xz
    if [ $? -eq 0 ] && [ -s fish.tar.xz ]; then
        # Check if we can extract it
        if tar -tf fish.tar.xz >/dev/null 2>&1; then
            tar -xf fish.tar.xz
            
            # List contents to see actual structure
            echo "📋 Archive contents:"
            ls -la
            
            # Find the fish binary - it might be in different locations
            FISH_BIN=$(find . -name "fish" -type f -executable | head -1)
            if [ -n "$FISH_BIN" ]; then
                echo "📦 Found fish binary at: $FISH_BIN"
                cp "$FISH_BIN" "$HOME/.local/bin/"
                
                # Find and copy fish data files
                mkdir -p "$HOME/.local/share/fish"
                FISH_SHARE=$(find . -path "*/share/fish" -type d | head -1)
                if [ -n "$FISH_SHARE" ]; then
                    echo "📦 Found fish data at: $FISH_SHARE"
                    cp -r "$FISH_SHARE"/* "$HOME/.local/share/fish/" 2>/dev/null || true
                fi
            else
                echo "❌ Could not find fish binary in archive - this is a source archive, not binary"
                echo "📋 Archive structure:"
                find . -type f -name "*fish*" | head -10
                cd /
                rm -rf "$TEMP_DIR"
                return 1
            fi
        else
            echo "❌ Downloaded file is not a valid tar archive"
            cd /
            rm -rf "$TEMP_DIR"
            return 1
        fi
    else
        echo "❌ All fish download methods failed"
        cd /
        rm -rf "$TEMP_DIR"
        return 1
    fi
    
    # Clean up
    cd /
    rm -rf "$TEMP_DIR"
    
    # Verify the installation
    if [ -f "$HOME/.local/bin/fish" ] && [ -x "$HOME/.local/bin/fish" ]; then
        echo "✅ Fish binary installed to ~/.local/bin/fish"
        return 0
    else
        echo "❌ Fish binary installation failed - file not found or not executable"
        return 1
    fi
}

# Function to install fish from source (fallback)
install_fish_from_source() {
    echo "📦 Installing fish from source to ~/.local/..."
    
    # Check if we have required build tools
    if ! command -v cmake &> /dev/null || ! command -v make &> /dev/null || ! command -v gcc &> /dev/null; then
        echo "❌ Required build tools not found (cmake, make, gcc)"
        echo "Cannot build from source without these tools"
        return 1
    fi
    
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
    # Try to install fish binary first
    if install_fish_binary; then
        echo "✅ Fish binary installation successful"
    else
        echo "⚠️  Binary installation failed, trying source build..."
        if install_fish_from_source; then
            echo "✅ Fish source build successful"
        else
            echo "❌ Both binary and source installation failed"
            echo "Fish installation unsuccessful, but continuing with enhanced tools..."
        fi
    fi
fi

# Update PATH to include local bin
export PATH="$HOME/.local/bin:$PATH"

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
set -x PATH "$HOME/.local/bin" $PATH

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
echo "1. Add ~/.local/bin to your PATH in ~/.bashrc or ~/.profile:"
echo "   echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
echo "2. To use fish as your default shell (if allowed), run:"
echo "   chsh -s \$HOME/.local/bin/fish"
echo "3. Or simply start fish manually: ~/.local/bin/fish"
echo ""
echo "📁 Fish binary: $HOME/.local/bin/fish"
echo "📁 Configuration: $HOME/.config/fish/config.fish"
echo "📁 Enhanced tools: ~/.local/bin/{bat,eza,oh-my-posh,zoxide,duf}"
echo "🚀 All tools installed as pre-compiled binaries - no build tools required!"
echo "📁 Dotfiles link: $HOME/.dotfiles"