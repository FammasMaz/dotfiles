#!/bin/bash

# Shell Configuration Setup Script
# Handles Fish and Zsh configuration, symlinking, and plugin installation

set -e

# Get the absolute path of the dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source utility functions and OS detection
source "$DOTFILES_DIR/lib/utils.sh"
source "$DOTFILES_DIR/lib/os_detect.sh"

# Default to fish if no shell specified
SHELL_NAME="${1:-fish}"

# Setup Fish shell configuration
setup_fish() {
    header "🐠 Setting up Fish Shell"
    
    # Ensure fish is installed
    if ! command_exists fish; then
        log_error "Fish shell is not installed. Please install it first."
        return 1
    fi
    
    # Create fish config directory
    local fish_config_dir="$HOME/.config/fish"
    mkdir -p "$fish_config_dir"
    
    # Symlink fish configuration files
    if [ -f "$DOTFILES_DIR/config/fish/config.fish" ]; then
        safe_symlink "$DOTFILES_DIR/config/fish/config.fish" "$fish_config_dir/config.fish"
    else
        log_warning "Fish config file not found: $DOTFILES_DIR/config/fish/config.fish"
    fi
    
    # Symlink fish functions if they exist
    if [ -d "$DOTFILES_DIR/config/fish/functions" ]; then
        safe_symlink "$DOTFILES_DIR/config/fish/functions" "$fish_config_dir/functions"
    fi
    
    # Install fisher if not already installed
    install_fisher
    
    # Install fish plugins
    install_fish_plugins
    
    # Convert zsh history if it exists
    convert_zsh_history_to_fish
    
    # Offer to set as default shell
    if ! is_default_shell fish; then
        log_step "Fish shell configured successfully"
        change_default_shell fish
    else
        log_success "Fish is already your default shell"
    fi
}

# Setup Zsh configuration
setup_zsh() {
    header "🐚 Setting up Zsh Shell"
    
    # Ensure zsh is installed
    if ! command_exists zsh; then
        log_error "Zsh is not installed. Please install it first."
        return 1
    fi
    
    # Symlink zsh configuration
    if [ -f "$DOTFILES_DIR/config/zsh/.zshrc" ]; then
        safe_symlink "$DOTFILES_DIR/config/zsh/.zshrc" "$HOME/.zshrc"
    else
        log_warning "Zsh config file not found: $DOTFILES_DIR/config/zsh/.zshrc"
    fi
    
    # Install zsh plugins
    install_zsh_plugins
    
    # Offer to set as default shell
    if ! is_default_shell zsh; then
        log_step "Zsh configured successfully"
        change_default_shell zsh
    else
        log_success "Zsh is already your default shell"
    fi
}

# Install fisher (fish plugin manager)
install_fisher() {
    if fish -c "type -q fisher" 2>/dev/null; then
        log_success "Fisher already installed"
        return 0
    fi
    
    log_step "Installing fisher (fish plugin manager)..."
    if fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher" 2>/dev/null; then
        log_success "Fisher installed successfully"
    else
        log_warning "Failed to install fisher"
        return 1
    fi
}

# Install fish plugins
install_fish_plugins() {
    if ! command_exists fish || ! fish -c "type -q fisher" 2>/dev/null; then
        log_warning "Fish or fisher not available, skipping plugin installation"
        return 1
    fi
    
    log_step "Installing fish plugins..."
    
    # List of plugins to install
    local plugins=(
        "jethrokuan/z"           # Directory jumping
        "PatrickF1/fzf.fish"     # Fuzzy finder integration
        "jorgebucaran/autopair.fish"  # Auto-close brackets and quotes
    )
    
    for plugin in "${plugins[@]}"; do
        log_info "Installing fish plugin: $plugin"
        fish -c "fisher install $plugin" 2>/dev/null || log_warning "Failed to install $plugin"
    done
    
    log_success "Fish plugins installation completed"
}

# Install zsh plugins (manual installation for compatibility)
install_zsh_plugins() {
    log_step "Setting up zsh plugins..."
    
    local zsh_plugins_dir="$HOME/.zsh/plugins"
    mkdir -p "$zsh_plugins_dir"
    
    # Install zsh-autosuggestions
    install_zsh_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
    
    # Install zsh-syntax-highlighting
    install_zsh_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
    
    log_success "Zsh plugins setup completed"
}

# Install a single zsh plugin
install_zsh_plugin() {
    local plugin_name="$1"
    local plugin_url="$2"
    local plugin_dir="$HOME/.zsh/plugins/$plugin_name"
    
    if [ -d "$plugin_dir" ]; then
        log_info "Updating $plugin_name..."
        cd "$plugin_dir" && git pull >/dev/null 2>&1 || log_warning "Failed to update $plugin_name"
    else
        log_info "Installing $plugin_name..."
        if git clone "$plugin_url" "$plugin_dir" >/dev/null 2>&1; then
            log_success "$plugin_name installed"
        else
            log_warning "Failed to install $plugin_name"
        fi
    fi
}

# Convert zsh history to fish format
convert_zsh_history_to_fish() {
    local zsh_history="$HOME/.zsh_history"
    local fish_history_dir="$HOME/.local/share/fish"
    local fish_history="$fish_history_dir/fish_history"
    
    if [ ! -f "$zsh_history" ]; then
        log_debug "No zsh history found to convert"
        return 0
    fi
    
    if [ -f "$fish_history" ] && [ -s "$fish_history" ]; then
        log_debug "Fish history already exists and is not empty, skipping conversion"
        return 0
    fi
    
    log_step "Converting zsh history to fish format..."
    
    # Create fish history directory
    mkdir -p "$fish_history_dir"
    
    # Simple conversion: extract commands from zsh history format
    # Zsh history format: : <timestamp>:<duration>;<command>
    if command_exists sed && command_exists grep; then
        # Extract commands and convert to fish format
        grep '^:' "$zsh_history" | sed 's/^:[^;]*;//' | while IFS= read -r cmd; do
            if [ -n "$cmd" ]; then
                printf -- "- cmd: %s\n  when: %d\n" "$cmd" "$(date +%s)" >> "$fish_history"
            fi
        done
        
        log_success "Zsh history converted to fish format"
    else
        log_warning "sed or grep not available, skipping history conversion"
    fi
}

# Setup shell-agnostic configurations
setup_shared_configs() {
    log_step "Setting up shared configurations..."
    
    # Create .dotfiles symlink for easy access
    safe_symlink "$DOTFILES_DIR" "$HOME/.dotfiles"
    
    # Setup gitconfig if available
    if [ -f "$DOTFILES_DIR/config/shared/.gitconfig" ]; then
        safe_symlink "$DOTFILES_DIR/config/shared/.gitconfig" "$HOME/.gitconfig"
    fi
    
    # Setup Starship configuration
    if [ -f "$DOTFILES_DIR/config/starship/starship.toml" ]; then
        safe_symlink "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship/starship.toml"
    fi
    
    log_success "Shared configurations setup completed"
}

# Initialize starship if available
setup_starship() {
    if ! command_exists starship; then
        log_debug "Starship not installed, skipping setup"
        return 0
    fi
    
    log_step "Configuring Starship prompt..."
    
    if [ -f "$DOTFILES_DIR/config/starship/starship.toml" ]; then
        safe_symlink "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship/starship.toml"
        log_success "Starship configuration linked"
    else
        log_warning "Starship config not found in dotfiles repository"
    fi
}

# Main shell setup function
main() {
    local shell_to_setup="$1"
    
    header "🐚 Shell Configuration Setup"
    echo "Target shell: $shell_to_setup"
    echo ""
    
    # Setup shared configurations first
    setup_shared_configs
    
    # Setup Starship prompt
    setup_starship
    
    # Setup the specified shell
    case "$shell_to_setup" in
        fish)
            setup_fish
            ;;
        zsh)
            setup_zsh
            ;;
        *)
            log_error "Unsupported shell: $shell_to_setup"
            log_info "Supported shells: fish, zsh"
            return 1
            ;;
    esac
    
    log_success "Shell configuration completed for $shell_to_setup"
    echo ""
    echo "🔄 Please restart your terminal or run: exec \$SHELL"
}

# Handle script being run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
