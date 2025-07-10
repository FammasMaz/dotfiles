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

# Get binary name for a package (handles special cases)
get_binary_name() {
    local package="$1"
    
    case "$package" in
        "miniconda"|"anaconda")
            echo "conda"
            ;;
        "thefuck")
            echo "fuck"
            ;;
        *)
            echo "$package"
            ;;
    esac
}

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
    
    # Install each package and track results
    local failed_packages=""
    local installed_count=0
    local failed_count=0
    
    for package in "${package_array[@]}"; do
        if [ -n "$package" ]; then  # Skip empty strings
            local binary_name
            binary_name=$(get_binary_name "$package")
            if install_single_package "$package" "$binary_name"; then
                installed_count=$((installed_count + 1))
            else
                failed_count=$((failed_count + 1))
                if [ -n "$failed_packages" ]; then
                    failed_packages="$failed_packages, $package"
                else
                    failed_packages="$package"
                fi
            fi
        fi
    done
    
    # Summary
    if [ $failed_count -gt 0 ]; then
        log_warning "$failed_count package(s) failed to install: $failed_packages"
        log_info "$installed_count package(s) installed successfully"
    else
        log_success "All $installed_count packages installed successfully"
    fi
}

# Attempt to install a package into the user's local directories
install_package_user_space() {
    local package="$1"
    log_info "Attempting user-space installation for $package..."

    # Define package-to-manager heuristics here.
    # Using padded spaces to ensure whole-word matching.
    local pip_packages=" thefuck youtube-dl yt-dlp "
    local cargo_packages=" exa bat ripgrep fd-find rg "
    local conda_forge_packages=" fish zsh git curl wget "
    
    # Package name mappings for different managers
    local cargo_name="$package"
    case "$package" in
        "fd-find") cargo_name="fd-find" ;;
        "ripgrep") cargo_name="ripgrep" ;;
        "bat") cargo_name="bat" ;;
        "exa") cargo_name="exa" ;;
    esac

    # Strategy 1: Pip for known Python packages
    if [ -n "$USER_PIP_CMD" ]; then
        case "$pip_packages" in
            *" $package "*)
                log_info "-> Found match for '$package', trying 'pip install --user'..."
                if "$USER_PIP_CMD" install --user "$package"; then
                    log_success "Installed $package via pip."
                    return 0
                fi
                ;;
        esac
    fi

    # Strategy 2: Cargo for known Rust crates
    if [ -n "$USER_CARGO_CMD" ]; then
        case "$cargo_packages" in
            *" $package "*)
                log_info "-> Found match for '$package', trying 'cargo install'..."
                if "$USER_CARGO_CMD" install "$cargo_name"; then
                    log_success "Installed $package via cargo."
                    return 0
                fi
                ;;
        esac
    fi

    # Strategy 3: Conda-forge for packages not in default channels
    if [ -n "$USER_CONDA_CMD" ]; then
        case "$conda_forge_packages" in
            *" $package "*)
                log_info "-> Found match for '$package', trying 'conda install' from conda-forge..."
                if "$USER_CONDA_CMD" install -c conda-forge -y "$package"; then
                    log_success "Installed $package via conda-forge."
                    return 0
                fi
                ;;
        esac
    fi

    # Strategy 4: Fallback to default Conda (if available)
    # Only try this for packages not known to fail
    if [ -n "$USER_CONDA_CMD" ]; then
        case "$cargo_packages" in
            *" $package "*) 
                log_info "-> Skipping conda fallback for Rust package '$package'"
                ;;
            *)
                log_info "-> Trying conda default channels as fallback..."
                if "$USER_CONDA_CMD" install -y "$package"; then
                    log_success "Installed $package via conda."
                    return 0
                fi
                ;;
        esac
    fi

    # Strategy 5: Binary download for tools without cargo/conda
    case "$package" in
        "bat"|"eza"|"ripgrep"|"fd-find")
            log_info "-> Trying binary download for '$package'..."
            if install_binary_from_github "$package"; then
                log_success "Installed $package via binary download."
                return 0
            fi
            ;;
    esac

    log_debug "No user-space installation method succeeded for '$package'."
    return 1
}

# Install binary from GitHub releases for common tools
install_binary_from_github() {
    local package="$1"
    local bin_dir="$HOME/.local/bin"
    
    # Ensure ~/.local/bin exists
    mkdir -p "$bin_dir"
    
    # Get system architecture
    local arch=$(uname -m)
    case "$arch" in
        "x86_64") arch="x86_64" ;;
        "aarch64"|"arm64") arch="aarch64" ;;
        *) log_warning "Unsupported architecture: $arch"; return 1 ;;
    esac
    
    # Define GitHub repos and binary patterns
    local repo=""
    local binary_name=""
    local pattern=""
    
    case "$package" in
        "bat")
            repo="sharkdp/bat"
            binary_name="bat"
            pattern="bat-.*-${arch}-unknown-linux-musl.tar.gz"
            ;;
        "eza")
            repo="eza-community/eza"
            binary_name="eza"
            pattern="eza_${arch}-unknown-linux-musl.tar.gz"
            ;;
        "ripgrep")
            repo="BurntSushi/ripgrep"
            binary_name="rg"
            pattern="ripgrep-.*-${arch}-unknown-linux-musl.tar.gz"
            ;;
        "fd-find")
            repo="sharkdp/fd"
            binary_name="fd"
            pattern="fd-.*-${arch}-unknown-linux-musl.tar.gz"
            ;;
        *)
            log_debug "No binary download configured for '$package'"
            return 1
            ;;
    esac
    
    log_info "Downloading $package from GitHub releases..."
    
    # Get latest release URL
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local download_url
    
    if command -v jq >/dev/null 2>&1; then
        # Use jq if available
        download_url=$(curl -s "$api_url" | jq -r ".assets[] | select(.name | test(\"$pattern\")) | .browser_download_url" | head -1)
    else
        # Fallback without jq
        download_url=$(curl -s "$api_url" | grep -o "\"browser_download_url\":[^\"]*\"[^\"]*$pattern[^\"]*\"" | cut -d'"' -f4 | head -1)
    fi
    
    if [ -z "$download_url" ]; then
        log_warning "Could not find download URL for $package ($pattern)"
        return 1
    fi
    
    # Download and extract
    local temp_dir=$(mktemp -d)
    local archive_name="${download_url##*/}"
    
    log_info "Downloading from: $download_url"
    if curl -L -o "$temp_dir/$archive_name" "$download_url"; then
        cd "$temp_dir"
        
        # Extract archive
        if tar -xzf "$archive_name"; then
            # Find the binary and copy it
            local extracted_binary=$(find . -name "$binary_name" -type f -executable | head -1)
            if [ -n "$extracted_binary" ]; then
                cp "$extracted_binary" "$bin_dir/$binary_name"
                chmod +x "$bin_dir/$binary_name"
                log_success "Installed $binary_name to $bin_dir"
                
                # Cleanup
                rm -rf "$temp_dir"
                return 0
            else
                log_warning "Could not find binary '$binary_name' in extracted archive"
            fi
        else
            log_warning "Failed to extract $archive_name"
        fi
    else
        log_warning "Failed to download $package"
    fi
    
    # Cleanup on failure
    rm -rf "$temp_dir"
    return 1
}

# Install a single package with enhanced detection and migration support
install_single_package() {
    local package="$1"
    local binary="${2:-$package}"  # Binary name defaults to package name
    
    log_debug "Checking package: $package (binary: $binary)"
    
    # Check package status: not_installed, managed, external
    local status
    status=$(check_package_status "$package" "$binary")
    
    case "$status" in
        "not_installed")
            log_info "Installing $package..."
            
            # If --no-sudo is active, attempt user-space installation first.
            if [ "${NO_SUDO:-0}" -eq 1 ]; then
                if install_package_user_space "$package"; then
                    return 0 # Success is logged within the helper
                else
                    log_warning "Failed to install $package via user-space methods"
                    return 1
                fi
            fi

            # --- Standard system installation logic ---
            if [ -z "$INSTALL_CMD" ]; then
                log_warning "System installer not available (or --no-sudo used on a sudo-based system). Skipping $package."
                return 1
            fi
            
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
            ;;
            
        "managed")
            log_success "$package already managed by $PACKAGE_MANAGER"
            return 0
            ;;
            
        "external")
            # Handle external installations
            handle_external_package "$package" "$binary"
            ;;
    esac
}

# Handle packages that are installed externally (not via package manager)
handle_external_package() {
    local package="$1"
    local binary="$2"
    local binary_path
    binary_path=$(get_command_path "$binary")
    
    # Special handling for specific packages
    case "$package" in
        "miniconda"|"anaconda")
            handle_conda_external "$binary_path"
            ;;
        *)
            # For simple tools like git, curl, etc., just skip with info
            log_info "Found external installation of $package at $binary_path"
            
            if confirm "Install $PACKAGE_MANAGER version anyway? (may cause conflicts)" "n"; then
                log_info "Installing $package via $PACKAGE_MANAGER..."
                if eval "$INSTALL_CMD $package"; then
                    log_success "$package installed via $PACKAGE_MANAGER"
                    log_warning "You now have multiple versions. Ensure PATH is configured correctly."
                else
                    log_warning "Failed to install $package via $PACKAGE_MANAGER"
                fi
            else
                log_info "Skipping $PACKAGE_MANAGER installation of $package"
            fi
            ;;
    esac
}

# Handle external conda installations
handle_conda_external() {
    local conda_path="$1"
    
    if prompt_conda_migration "$conda_path"; then
        # User chose to migrate
        if migrate_conda_installation "$conda_path" "$INSTALL_CMD"; then
            log_success "Conda migration completed successfully"
        else
            log_error "Conda migration failed"
            return 1
        fi
    else
        # User chose to skip
        log_info "Keeping existing conda installation at $conda_path"
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
    if [ "${NO_SUDO:-0}" -eq 1 ]; then
        log_info "Skipping package manager update due to --no-sudo mode."
        return 0
    fi

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