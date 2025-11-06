#!/bin/bash

# Universal Dotfiles Setup Script
# Streamlined, idempotent setup for Fish shell (preferred) and Zsh compatibility
# Works across macOS and Linux distributions

set -e  # Exit on any error

# Get the absolute path of the dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions and OS detection
source "$DOTFILES_DIR/lib/utils.sh"
source "$DOTFILES_DIR/lib/os_detect.sh"

# Configuration
readonly PREFERRED_SHELL="fish"
readonly FALLBACK_SHELL="zsh"

# Display banner
show_banner() {
    header "🐠 Universal Dotfiles Setup"
    echo "  Fish shell preferred, Zsh compatible"
    echo "  Cross-platform: macOS & Linux"
    echo ""
    show_system_info
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if we're in the dotfiles directory
    if [ ! -f "$DOTFILES_DIR/setup.sh" ]; then
        log_error "Setup script not found in expected location: $DOTFILES_DIR"
        exit 1
    fi
    
    # Check for git (needed for some installations)
    if ! command_exists git; then
        log_warning "Git not found. Some features may not work properly."
    fi
    
    # Check for curl (needed for downloads)
    if ! command_exists curl; then
        log_error "curl is required but not found. Please install curl first."
        exit 1
    fi
    
    log_success "Prerequisites check complete"
}

# Install packages using the package installer
install_packages() {
    log_step "Installing packages..."
    
    if [ -f "$DOTFILES_DIR/install/packages.sh" ]; then
        bash "$DOTFILES_DIR/install/packages.sh"
    else
        log_warning "Package installer not found: $DOTFILES_DIR/install/packages.sh"
    fi
}

# Setup shell configuration
setup_shell() {
    log_step "Setting up shell configuration..."
    
    local chosen_shell=""
    
    # Try to install and setup preferred shell (fish)
    if command_exists "$PREFERRED_SHELL" || attempt_shell_install "$PREFERRED_SHELL"; then
        log_info "Setting up $PREFERRED_SHELL as primary shell"
        chosen_shell="$PREFERRED_SHELL"
    elif command_exists "$FALLBACK_SHELL" || attempt_shell_install "$FALLBACK_SHELL"; then
        log_warning "$PREFERRED_SHELL not available, falling back to $FALLBACK_SHELL"
        chosen_shell="$FALLBACK_SHELL"
    else
        log_error "Neither $PREFERRED_SHELL nor $FALLBACK_SHELL could be installed"
        return 1
    fi
    
    # Configure the chosen shell
    if [ -f "$DOTFILES_DIR/install/shell.sh" ]; then
        bash "$DOTFILES_DIR/install/shell.sh" "$chosen_shell"
    else
        log_warning "Shell installer not found: $DOTFILES_DIR/install/shell.sh"
        setup_shell_fallback "$chosen_shell"
    fi
}

# Attempt to install a shell using the package manager
attempt_shell_install() {
    local shell_name="$1"

    if [ "${NO_SUDO:-0}" -eq 1 ]; then
        log_warning "Cannot install $shell_name due to --no-sudo. Setup will continue only if it's already installed."
        return 1
    fi
    
    if [ "$PACKAGE_MANAGER" = "unknown" ]; then
        log_warning "No package manager available to install $shell_name"
        return 1
    fi
    
    log_info "Attempting to install $shell_name..."
    
    case "$shell_name" in
        fish)
            install_packages fish
            ;;
        zsh)
            install_packages zsh
            ;;
        *)
            log_error "Unknown shell: $shell_name"
            return 1
            ;;
    esac
    
    # Verify installation
    if command_exists "$shell_name"; then
        log_success "$shell_name installed successfully"
        return 0
    else
        log_error "Failed to install $shell_name"
        return 1
    fi
}

# Fallback shell setup if the main installer isn't available
setup_shell_fallback() {
    local shell_name="$1"
    
    log_info "Using fallback shell configuration for $shell_name"
    
    case "$shell_name" in
        fish)
            setup_fish_fallback
            ;;
        zsh)
            setup_zsh_fallback
            ;;
    esac
}

# Fallback Fish configuration
setup_fish_fallback() {
    local fish_config_dir="$HOME/.config/fish"
    
    # Create fish config directory
    mkdir -p "$fish_config_dir"
    
    # Link config if available
    if [ -f "$DOTFILES_DIR/config/fish/config.fish" ]; then
        safe_symlink "$DOTFILES_DIR/config/fish/config.fish" "$fish_config_dir/config.fish"
    fi
    
    # Offer to change default shell
    if ! is_default_shell fish; then
        change_default_shell fish
    fi
}

# Fallback Zsh configuration
setup_zsh_fallback() {
    # Link .zshrc if available
    if [ -f "$DOTFILES_DIR/config/zsh/.zshrc" ]; then
        safe_symlink "$DOTFILES_DIR/config/zsh/.zshrc" "$HOME/.zshrc"
    fi
    
    # Offer to change default shell
    if ! is_default_shell zsh; then
        change_default_shell zsh
    fi
}

# Setup additional configurations
setup_additional_configs() {
    log_step "Setting up additional configurations..."
    
    # Create dotfiles symlink for easy access
    safe_symlink "$DOTFILES_DIR" "$HOME/.dotfiles"
    
    # Setup git configuration if available
    if [ -f "$DOTFILES_DIR/config/shared/.gitconfig" ]; then
        safe_symlink "$DOTFILES_DIR/config/shared/.gitconfig" "$HOME/.gitconfig"
    fi
    
    # Setup other shared configurations
    for config_file in "$DOTFILES_DIR/config/shared"/.??*; do
        if [ -f "$config_file" ] && [ "$(basename "$config_file")" != ".gitconfig" ]; then
            safe_symlink "$config_file" "$HOME/$(basename "$config_file")"
        fi
    done
}

# Setup development tools and environment
setup_development_environment() {
    log_step "Setting up development environment..."
    
    # Install fisher for fish (if fish is the chosen shell)
    if command_exists fish && ! fish -c "type -q fisher" 2>/dev/null; then
        log_info "Installing fisher (fish plugin manager)..."
        fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher" 2>/dev/null || true
    fi
    
    # Install common fish plugins
    if command_exists fish; then
        fish -c "fisher install jethrokuan/z" 2>/dev/null || true
        fish -c "fisher install PatrickF1/fzf.fish" 2>/dev/null || true
    fi
    
    # Initialize zoxide if available
    if command_exists zoxide; then
        log_debug "zoxide is available and will be initialized in shell configs"
    fi
    
    # Setup starship prompt configuration if available
    if [ -f "$DOTFILES_DIR/config/starship/starship.toml" ]; then
        safe_symlink "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship/starship.toml"
    fi
}

# Post-installation steps and recommendations
show_next_steps() {
    header "🎉 Setup Complete!"
    
    echo "Next steps:"
    echo ""
    
    # Shell-specific instructions
    if command_exists fish && is_default_shell fish; then
        echo "✅ Fish shell is configured and set as default"
    elif command_exists fish; then
        echo "🐠 Fish shell is configured. To set as default, run:"
        echo "   chsh -s $(command -v fish)"
    elif command_exists zsh && is_default_shell zsh; then
        echo "✅ Zsh is configured and set as default"
    elif command_exists zsh; then
        echo "🐚 Zsh is configured. To set as default, run:"
        echo "   chsh -s $(command -v zsh)"
    fi
    
    echo ""
    echo "🔄 Restart your terminal or run: exec \$SHELL"
    echo "📁 Your dotfiles are linked from: $DOTFILES_DIR"
    echo "🔗 Quick access via: ~/.dotfiles"
    
    if command_exists gh; then
        echo "🐙 GitHub CLI is available. Authenticate with: gh auth login"
    fi
    
    if setup_already_run; then
        echo ""
        echo "💡 Setup has been run before. This was an update/re-run."
    fi
    
    echo ""
    separator
}

# Main execution flow
main() {
    # Default flags
    export NO_SUDO=0
    export DEBUG=0

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --no-sudo)
                export NO_SUDO=1
                shift
                ;;
            --debug)
                export DEBUG=1
                shift
                ;;
            -h|--help)
                show_banner
                echo "Usage: $0 [--no-sudo] [--debug] [--help]"
                echo ""
                echo "Options:"
                echo "  --no-sudo  Run without attempting any sudo operations"
                echo "  --debug    Enable debug output"
                echo "  --help     Show this help message"
                echo ""
                echo "This script will:"
                echo "  1. Detect your OS and package manager"
                echo "  2. Install essential packages (skipped with --no-sudo)"
                echo "  3. Setup Fish shell (preferred) or Zsh (fallback)"
                echo "  4. Configure shell environments and tools"
                echo "  5. Create symlinks to configuration files"
                exit 0
                ;;
        esac
    done

    # Log mode information
    if [ "$NO_SUDO" -eq 1 ]; then
        log_info "Running in --no-sudo mode. Sudo-required operations will be skipped."
    fi
    
    if [ "$DEBUG" -eq 1 ]; then
        log_debug "Debug mode enabled"
    fi
    
    show_banner
    
    # Main setup flow
    check_prerequisites
    install_packages
    setup_shell
    setup_additional_configs
    setup_development_environment
    
    # Mark setup as complete
    mark_setup_complete
    
    show_next_steps
}

# Handle script being run directly vs sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
