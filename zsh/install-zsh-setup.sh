#!/bin/bash

# Zsh Setup Script for Linux
# This script installs zsh, sets it as default, installs plugins, and oh-my-posh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    elif type lsb_release >/dev/null 2>&1; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# Function to install zsh based on distribution
install_zsh() {
    local distro=$(detect_distro)
    print_step "Installing zsh for $distro distribution..."
    
    case $distro in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y zsh curl git
            ;;
        fedora)
            sudo dnf install -y zsh curl git
            ;;
        centos|rhel)
            sudo yum install -y zsh curl git
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm zsh curl git
            ;;
        opensuse*)
            sudo zypper install -y zsh curl git
            ;;
        alpine)
            sudo apk add zsh curl git
            ;;
        *)
            print_error "Unsupported distribution: $distro"
            print_warning "Please install zsh manually and run this script again"
            exit 1
            ;;
    esac
    
    print_status "Zsh installed successfully!"
}

# Function to set zsh as default shell
set_default_shell() {
    print_step "Setting zsh as default shell..."
    
    # Get zsh path
    ZSH_PATH=$(which zsh)
    
    if [ -z "$ZSH_PATH" ]; then
        print_error "Zsh not found in PATH"
        exit 1
    fi
    
    # Add zsh to /etc/shells if not already there
    if ! grep -q "$ZSH_PATH" /etc/shells; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells
        print_status "Added zsh to /etc/shells"
    fi
    
    # Change default shell for current user
    sudo chsh -s "$ZSH_PATH" "$USER"
    print_status "Default shell changed to zsh for user: $USER"
    print_warning "You'll need to log out and log back in for the shell change to take effect"
}

# Function to install zsh-autosuggestions
install_autosuggestions() {
    print_step "Installing zsh-autosuggestions..."
    
    # Create zsh plugins directory
    mkdir -p ~/.zsh/plugins
    
    # Clone zsh-autosuggestions
    if [ -d ~/.zsh/plugins/zsh-autosuggestions ]; then
        print_warning "zsh-autosuggestions already exists, updating..."
        cd ~/.zsh/plugins/zsh-autosuggestions && git pull
    else
        git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/plugins/zsh-autosuggestions
    fi
    
    print_status "zsh-autosuggestions installed successfully!"
}

# Function to install zsh-syntax-highlighting
install_syntax_highlighting() {
    print_step "Installing zsh-syntax-highlighting..."
    
    # Create zsh plugins directory if not exists
    mkdir -p ~/.zsh/plugins
    
    # Clone zsh-syntax-highlighting
    if [ -d ~/.zsh/plugins/zsh-syntax-highlighting ]; then
        print_warning "zsh-syntax-highlighting already exists, updating..."
        cd ~/.zsh/plugins/zsh-syntax-highlighting && git pull
    else
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/plugins/zsh-syntax-highlighting
    fi
    
    print_status "zsh-syntax-highlighting installed successfully!"
}

# Function to install oh-my-posh
install_oh_my_posh() {
    print_step "Installing oh-my-posh..."
    
    # Create local bin directory
    mkdir -p ~/.local/bin
    
    # Download and install oh-my-posh
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    fi
    
    print_status "oh-my-posh installed successfully!"
}

# Function to create/update .zshrc
setup_zshrc() {
    print_step "Setting up .zshrc configuration..."
    
    # Backup existing .zshrc if it exists
    if [ -f ~/.zshrc ]; then
        cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
        print_status "Backed up existing .zshrc"
    fi
    
    # Create new .zshrc with plugin configurations
    cat > ~/.zshrc << 'EOF'
# Zsh configuration

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE

# General options
setopt AUTO_CD
setopt CORRECT
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END

# Load zsh-autosuggestions
if [ -f ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    # Configure autosuggestions
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# Load zsh-syntax-highlighting (must be last)
if [ -f ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Initialize oh-my-posh with atomic theme
if command -v oh-my-posh &> /dev/null; then
    eval "$(oh-my-posh init zsh --config ~/.cache/oh-my-posh/themes/atomic.omp.json)"
fi

# Basic aliases
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

# Load additional configurations from ~/.zsh/config/ if it exists
if [ -d ~/.zsh/config ]; then
    for config in ~/.zsh/config/*.zsh; do
        [ -r "$config" ] && source "$config"
    done
fi
EOF
    
    print_status ".zshrc configuration created!"
}

# Function to setup oh-my-posh themes
setup_oh_my_posh_themes() {
    print_step "Setting up oh-my-posh themes..."
    
    # Create themes directory
    mkdir -p ~/.cache/oh-my-posh/themes
    
    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Copy the atomic theme from the script directory if it exists
    if [ -f "$SCRIPT_DIR/atomic.omp.json" ]; then
        cp "$SCRIPT_DIR/atomic.omp.json" ~/.cache/oh-my-posh/themes/atomic.omp.json
        print_status "Copied atomic.omp.json theme from dotfiles directory"
    else
        print_warning "atomic.omp.json not found in script directory, downloading agnoster theme as fallback"
        curl -s https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/agnoster.omp.json -o ~/.cache/oh-my-posh/themes/atomic.omp.json
    fi
    
    print_status "oh-my-posh theme setup complete!"
    print_status "Using atomic theme as default"
    print_status "You can change themes by modifying the oh-my-posh config line in ~/.zshrc"
    print_status "Available themes: https://ohmyposh.dev/docs/themes"
}

# Main execution
main() {
    print_status "Starting Zsh setup script..."
    echo
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please don't run this script as root"
        exit 1
    fi
    
    # Check if zsh is already installed
    if command -v zsh &> /dev/null; then
        print_warning "Zsh is already installed"
        ZSH_VERSION=$(zsh --version)
        print_status "Current version: $ZSH_VERSION"
    else
        install_zsh
    fi
    
    # Set zsh as default shell
    if [ "$SHELL" != "$(which zsh)" ]; then
        set_default_shell
    else
        print_status "Zsh is already the default shell"
    fi
    
    # Install plugins
    install_autosuggestions
    install_syntax_highlighting
    
    # Install oh-my-posh
    install_oh_my_posh
    
    # Setup configuration
    setup_zshrc
    setup_oh_my_posh_themes
    
    echo
    print_status "✅ Zsh setup completed successfully!"
    echo
    print_status "Next steps:"
    echo "  1. Log out and log back in (or restart your terminal)"
    echo "  2. Your new shell will be zsh with autosuggestions and syntax highlighting"
    echo "  3. oh-my-posh is configured with the agnoster theme"
    echo "  4. You can customize your setup by editing ~/.zshrc"
    echo
    print_status "To test immediately, run: exec zsh"
}

# Run main function
main "$@" 