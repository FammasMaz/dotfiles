#!/bin/bash

# Robust OS and package manager detection library
# Based on modern best practices for cross-platform compatibility

# Global variables to be set by detect_os() and detect_package_manager()
export OS=""
export DISTRO=""
export PACKAGE_MANAGER=""
export INSTALL_CMD=""
export UPDATE_CMD=""

# User-space package manager commands
export USER_CONDA_CMD=""
export USER_PIP_CMD=""
export USER_CARGO_CMD=""

# Detect operating system
detect_os() {
    case "$OSTYPE" in
        darwin*)
            OS="macos"
            ;;
        linux*)
            OS="linux"
            ;;
        msys*|mingw*|cygwin*)
            OS="windows"
            ;;
        *)
            OS="unknown"
            ;;
    esac
    
    # For Linux, also detect distribution
    if [ "$OS" = "linux" ]; then
        detect_linux_distro
    fi
}

# Detect Linux distribution
detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        # Modern standard method
        . /etc/os-release
        DISTRO="${ID}"
    elif [ -f /etc/lsb-release ]; then
        # LSB method
        . /etc/lsb-release
        DISTRO="${DISTRIB_ID,,}"  # Convert to lowercase
    elif [ -f /etc/redhat-release ]; then
        # Red Hat family
        DISTRO="rhel"
    elif [ -f /etc/debian_version ]; then
        # Debian family
        DISTRO="debian"
    else
        DISTRO="unknown"
    fi
}

# Detect available package manager with priority order
detect_package_manager() {
    # Priority order: brew > apt > dnf > pacman > zypper > apk > yum
    # This handles cases where multiple package managers exist
    
    if command -v brew >/dev/null 2>&1; then
        PACKAGE_MANAGER="brew"
        INSTALL_CMD="brew install"
        UPDATE_CMD="brew update && brew upgrade"
    elif command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
        if [ "${NO_SUDO:-0}" -eq 0 ]; then
            INSTALL_CMD="sudo apt-get install -y"
            UPDATE_CMD="sudo apt-get update && sudo apt-get upgrade -y"
        fi
    elif command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
        if [ "${NO_SUDO:-0}" -eq 0 ]; then
            INSTALL_CMD="sudo dnf install -y"
            UPDATE_CMD="sudo dnf check-update && sudo dnf upgrade -y"
        fi
    elif command -v pacman >/dev/null 2>&1; then
        PACKAGE_MANAGER="pacman"
        if [ "${NO_SUDO:-0}" -eq 0 ]; then
            INSTALL_CMD="sudo pacman -S --noconfirm"
            UPDATE_CMD="sudo pacman -Syu --noconfirm"
        fi
    elif command -v zypper >/dev/null 2>&1; then
        PACKAGE_MANAGER="zypper"
        if [ "${NO_SUDO:-0}" -eq 0 ]; then
            INSTALL_CMD="sudo zypper install -y"
            UPDATE_CMD="sudo zypper refresh && sudo zypper update -y"
        fi
    elif command -v apk >/dev/null 2>&1; then
        PACKAGE_MANAGER="apk"
        if [ "${NO_SUDO:-0}" -eq 0 ]; then
            INSTALL_CMD="sudo apk add"
            UPDATE_CMD="sudo apk update && sudo apk upgrade"
        fi
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
        if [ "${NO_SUDO:-0}" -eq 0 ]; then
            INSTALL_CMD="sudo yum install -y"
            UPDATE_CMD="sudo yum check-update && sudo yum update -y"
        fi
    else
        PACKAGE_MANAGER="unknown"
        INSTALL_CMD=""
        UPDATE_CMD=""
    fi
}

# Check if a package is installed via the detected package manager
is_package_installed() {
    local package="$1"
    
    case "$PACKAGE_MANAGER" in
        brew)
            brew list "$package" >/dev/null 2>&1
            ;;
        apt)
            dpkg -l | grep -q "^ii  $package "
            ;;
        dnf)
            dnf list installed "$package" >/dev/null 2>&1
            ;;
        pacman)
            pacman -Q "$package" >/dev/null 2>&1
            ;;
        zypper)
            zypper se -i "$package" >/dev/null 2>&1
            ;;
        apk)
            apk info -e "$package" >/dev/null 2>&1
            ;;
        yum)
            yum list installed "$package" >/dev/null 2>&1
            ;;
        *)
            # Fallback: check if command exists
            command -v "$package" >/dev/null 2>&1
            ;;
    esac
}

# Enhanced package status detection
# Returns: not_installed, managed, external
check_package_status() {
    local package="$1"
    local binary="${2:-$package}"  # Default binary name to package name
    
    # Check if the binary is available in PATH
    if ! command -v "$binary" >/dev/null 2>&1; then
        echo "not_installed"
        return 0
    fi
    
    # Check if package is managed by the current package manager
    if is_package_installed "$package"; then
        echo "managed"
        return 0
    fi
    
    echo "external"
    return 0
}

# Get the installation path of a command
get_command_path() {
    local binary="$1"
    command -v "$binary" 2>/dev/null
}

# Install packages using detected package manager
install_packages() {
    local packages=("$@")
    
    if [ "$PACKAGE_MANAGER" = "unknown" ]; then
        echo "❌ No supported package manager found"
        return 1
    fi
    
    echo "📦 Installing packages using $PACKAGE_MANAGER: ${packages[*]}"
    
    # First update package lists/repos
    if [ -n "$UPDATE_CMD" ]; then
        eval "$UPDATE_CMD" >/dev/null 2>&1 || true
    fi
    
    # Install packages
    for package in "${packages[@]}"; do
        if ! is_package_installed "$package"; then
            echo "📦 Installing $package..."
            eval "$INSTALL_CMD $package"
        else
            echo "✅ $package already installed"
        fi
    done
}

# Display system information
show_system_info() {
    echo "🖥️  System Information:"
    echo "   OS: $OS"
    if [ "$OS" = "linux" ]; then
        echo "   Distribution: $DISTRO"
    fi
    echo "   Package Manager: $PACKAGE_MANAGER"
    echo "   Architecture: $(uname -m)"
}

# Detect available user-space package managers
detect_user_managers() {
    # Detect conda (handle missing conda gracefully for lazy loading)
    if command -v conda >/dev/null 2>&1; then
        USER_CONDA_CMD=$(command -v conda 2>/dev/null)
    else
        USER_CONDA_CMD=""
    fi

    # Detect pip
    if command -v pip3 >/dev/null 2>&1; then
        USER_PIP_CMD="pip3"
    elif command -v pip >/dev/null 2>&1; then
        USER_PIP_CMD="pip"
    else
        USER_PIP_CMD=""
    fi

    # Detect cargo (also check the default cargo path in case it's not in the current shell's PATH yet)
    if command -v cargo >/dev/null 2>&1; then
        USER_CARGO_CMD="cargo"
    elif [ -f "$HOME/.cargo/bin/cargo" ]; then
        USER_CARGO_CMD="$HOME/.cargo/bin/cargo"
    else
        USER_CARGO_CMD=""
    fi
}

# Initialize detection (call this to populate variables)
init_detection() {
    detect_os
    detect_package_manager
    detect_user_managers
}

# Auto-initialize when sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    # Script is being sourced, auto-initialize
    init_detection
fi