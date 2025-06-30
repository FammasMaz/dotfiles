#!/bin/bash

# Package Installation Script
# Installs packages based on detected OS and package manager
# Uses the robust detection from lib/os_detect.sh

set -e

# Get the absolute path of the dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source utility functions and OS detection
source "$DOTFILES_DIR/lib/utils.sh"
source "$DOTFILES_DIR/lib/os_detect.sh"

# Read packages from a file, filtering out comments and empty lines
read_package_list() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log_debug "Package list not found: $file"
        return 1
    fi
    
    # Filter out comments (lines starting with #) and empty lines
    grep -v '^#' "$file" | grep -v '^[[:space:]]*$' | tr '\n' ' '
}

# Install packages from a package list file
install_from_list() {
    local list_file="$1"
    local description="$2"
    
    if [ ! -f "$list_file" ]; then
        log_debug "Skipping $description (file not found: $list_file)"
        return 0
    fi
    
    log_step "Installing $description..."
    
    local packages
    packages=$(read_package_list "$list_file")
    
    if [ -z "$packages" ]; then
        log_debug "No packages found in $list_file"
        return 0
    fi
    
    log_info "Packages to install: $packages"
    
    # Convert space-separated string to array
    local package_array
    read -ra package_array <<< "$packages"
    
    # Install each package
    for package in "${package_array[@]}"; do
        if [ -n "$package" ]; then  # Skip empty strings
            install_single_package "$package"
        fi
    done
}

# Install a single package with error handling
install_single_package() {
    local package="$1"
    
    # Check if already installed
    if is_package_installed "$package"; then
        log_success "$package already installed"
        return 0
    fi
    
    log_info "Installing $package..."
    
    # Install using the detected package manager
    if [ "$PACKAGE_MANAGER" = "unknown" ]; then
        log_error "No supported package manager found for installing $package"
        return 1
    fi
    
    # Execute install command
    if eval "$INSTALL_CMD $package"; then
        log_success "$package installed successfully"
    else
        log_warning "Failed to install $package (continuing with other packages)"
        return 1
    fi
}

# Special handling for packages that need custom installation
install_special_packages() {
    log_step "Installing special packages..."
    
    # Install Oh My Posh if not available via package manager
    if ! command_exists oh-my-posh && [ "$OS" = "linux" ]; then
        log_info "Installing Oh My Posh..."
        curl -s https://ohmyposh.dev/install.sh | bash -s -- -d ~/.local/bin
    fi
    
    # Install Miniconda on Linux (since it's not available via most package managers)
    if [ "$OS" = "linux" ] && [ ! -d "$HOME/miniconda3" ]; then
        install_miniconda_linux
    fi
    
    # Install fisher for fish shell
    if command_exists fish && ! fish -c "type -q fisher" 2>/dev/null; then
        log_info "Installing fisher (fish plugin manager)..."
        fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher" 2>/dev/null || true
    fi
}

# Install Miniconda on Linux
install_miniconda_linux() {
    log_info "Installing Miniconda3 for Linux..."
    
    local miniconda_url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    local installer_path="/tmp/miniconda.sh"
    
    # Download Miniconda installer
    if curl -o "$installer_path" "$miniconda_url"; then
        # Install Miniconda
        bash "$installer_path" -b -p "$HOME/miniconda3"
        rm "$installer_path"
        
        # Initialize conda for available shells
        if [ -f "$HOME/miniconda3/bin/conda" ]; then
            "$HOME/miniconda3/bin/conda" init bash 2>/dev/null || true
            if command_exists zsh; then
                "$HOME/miniconda3/bin/conda" init zsh 2>/dev/null || true
            fi
            if command_exists fish; then
                "$HOME/miniconda3/bin/conda" init fish 2>/dev/null || true
            fi
        fi
        
        log_success "Miniconda3 installed successfully"
    else
        log_warning "Failed to download Miniconda installer"
    fi
}

# Update package manager repositories
update_package_manager() {
    if [ "$PACKAGE_MANAGER" = "unknown" ]; then
        log_warning "No package manager detected, skipping update"
        return 1
    fi
    
    log_step "Updating package manager ($PACKAGE_MANAGER)..."
    
    # Only update, don't upgrade existing packages (safer)
    case "$PACKAGE_MANAGER" in
        brew)
            brew update
            ;;
        apt)
            sudo apt-get update
            ;;
        dnf)
            sudo dnf check-update || true  # dnf check-update returns 100 if updates available
            ;;
        pacman)
            sudo pacman -Sy
            ;;
        zypper)
            sudo zypper refresh
            ;;
        apk)
            sudo apk update
            ;;
        yum)
            sudo yum check-update || true
            ;;
        *)
            log_warning "Don't know how to update $PACKAGE_MANAGER"
            return 1
            ;;
    esac
    
    log_success "Package manager updated"
}

# Install package manager if missing (Homebrew on macOS)
install_package_manager() {
    if [ "$OS" = "macos" ] && ! command_exists brew; then
        log_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        
        # Re-run detection after installing Homebrew
        detect_package_manager
        
        log_success "Homebrew installed successfully"
    fi
}

# Main package installation process
main() {
    header "📦 Package Installation"
    
    # Install package manager if needed
    install_package_manager
    
    # Ensure we have a package manager
    if [ "$PACKAGE_MANAGER" = "unknown" ]; then
        log_error "No supported package manager found. Cannot install packages."
        return 1
    fi
    
    # Update package manager
    update_package_manager
    
    # Install common packages
    install_from_list "$DOTFILES_DIR/install/packages.common" "common packages"
    
    # Install OS-specific packages
    case "$OS" in
        macos)
            install_from_list "$DOTFILES_DIR/install/packages.macos" "macOS packages"
            ;;
        linux)
            # Choose the appropriate Linux package list based on package manager
            case "$PACKAGE_MANAGER" in
                apt)
                    install_from_list "$DOTFILES_DIR/install/packages.linux_apt" "Linux (apt) packages"
                    ;;
                dnf|yum)
                    install_from_list "$DOTFILES_DIR/install/packages.linux_dnf" "Linux (dnf/yum) packages"
                    ;;
                pacman)
                    # Could add packages.linux_pacman if needed
                    log_info "Using common packages for Arch Linux"
                    ;;
                *)
                    log_info "Using common packages for $DISTRO Linux"
                    ;;
            esac
            ;;
        *)
            log_warning "Unknown OS: $OS. Only installing common packages."
            ;;
    esac
    
    # Install special packages
    install_special_packages
    
    log_success "Package installation completed"
}

# Handle script being run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi