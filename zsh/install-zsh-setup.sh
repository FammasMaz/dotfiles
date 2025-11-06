#!/bin/bash

# Zsh Setup Script for Linux
# This script installs zsh, sets it as default, installs plugins, and configures the Starship prompt

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
            sudo apt install -y zsh curl git zoxide
            ;;
        fedora)
            sudo dnf install -y zsh curl git zoxide
            ;;
        centos|rhel)
            sudo yum install -y zsh curl git zoxide
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm zsh curl git zoxide
            ;;
        opensuse*)
            sudo zypper install -y zsh curl git zoxide
            ;;
        alpine)
            sudo apk add zsh curl git zoxide
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

# Function to install starship prompt
install_starship() {
    if command -v starship >/dev/null 2>&1; then
        print_status "Starship already installed"
        return
    fi
    
    print_step "Installing starship prompt..."
    
    # Create local bin directory
    mkdir -p ~/.local/bin
    
    # Download and install starship
    curl -sS https://starship.rs/install.sh | sh -s -- -b ~/.local/bin
    
    if [ -f "$HOME/.local/bin/starship" ]; then
        chmod +x "$HOME/.local/bin/starship"
        print_status "Starship installed successfully!"
    else
        print_warning "Unable to verify starship installation. Check the install script output."
    fi
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

# Starship prompt
if command -v starship &> /dev/null; then
    export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
    eval "$(starship init zsh)"
fi

# Initialize zoxide
eval "$(zoxide init zsh)"

# Basic aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias cd='z'

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

# Function to link starship configuration
setup_starship_config() {
    print_step "Linking Starship configuration..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    DOTFILES_DIR="$SCRIPT_DIR/.."
    
    # Ensure dotfiles symlink exists for convenience
    if [ ! -L "$HOME/.dotfiles" ]; then
        ln -sf "$DOTFILES_DIR" "$HOME/.dotfiles"
        print_status "Created symlink to dotfiles directory at ~/.dotfiles"
    fi
    
    if [ -f "$DOTFILES_DIR/config/starship/starship.toml" ]; then
        mkdir -p ~/.config/starship
        ln -sf "$DOTFILES_DIR/config/starship/starship.toml" ~/.config/starship/starship.toml
        print_status "Starship configuration linked from dotfiles"
    else
        print_warning "Starship configuration not found in dotfiles repository"
    fi
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
    
    # Install starship prompt
    install_starship
    
    # Setup configuration
    setup_zshrc
    setup_starship_config
    
    echo
    print_status "✅ Zsh setup completed successfully!"
    echo
    print_status "Next steps:"
    echo "  1. Log out and log back in (or restart your terminal)"
    echo "  2. Your new shell will be zsh with autosuggestions and syntax highlighting"
    echo "  3. Starship prompt is configured with your dotfiles theme"
    echo "  4. You can customize your setup by editing ~/.config/starship/starship.toml"
    echo
    print_status "To test immediately, run: exec zsh"
}

# Run main function
main "$@"
