#!/bin/bash

# Utility functions for dotfiles setup
# Provides logging, idempotency checks, and common helper functions

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Get the dotfiles directory (assumes this script is in lib/ subdirectory)
get_dotfiles_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_debug() {
    if [ "${DEBUG:-}" = "1" ]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a file or directory exists
path_exists() {
    [ -e "$1" ]
}

# Check if a symlink exists and points to the correct target
symlink_correct() {
    local link_path="$1"
    local target_path="$2"
    
    [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$target_path" ]
}

# Create a symlink with backup if the target already exists
safe_symlink() {
    local source="$1"
    local target="$2"
    local backup_suffix="${3:-.backup}"
    
    if [ ! -e "$source" ]; then
        log_error "Source file does not exist: $source"
        return 1
    fi
    
    # If symlink already correct, nothing to do
    if symlink_correct "$target" "$source"; then
        log_debug "Symlink already correct: $target -> $source"
        return 0
    fi
    
    # Create target directory if it doesn't exist
    local target_dir
    target_dir="$(dirname "$target")"
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        log_debug "Created directory: $target_dir"
    fi
    
    # Backup existing file/link if it exists
    if [ -e "$target" ] || [ -L "$target" ]; then
        local backup_path="${target}${backup_suffix}.$(date +%Y%m%d_%H%M%S)"
        mv "$target" "$backup_path"
        log_info "Backed up existing file: $target -> $(basename "$backup_path")"
    fi
    
    # Create the symlink
    ln -sf "$source" "$target"
    log_success "Created symlink: $target -> $source"
}

# Check if running on macOS
is_macos() {
    [ "$(uname -s)" = "Darwin" ]
}

# Check if running on Linux
is_linux() {
    [ "$(uname -s)" = "Linux" ]
}

# Check if running with sudo privileges
has_sudo() {
    sudo -n true 2>/dev/null
}

# Prompt user for yes/no confirmation
confirm() {
    local prompt="$1"
    local default="${2:-n}"  # Default to 'n' if not specified
    
    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]"
    else
        prompt="$prompt [y/N]"
    fi
    
    read -p "$prompt: " -r response
    
    # If no response, use default
    if [ -z "$response" ]; then
        response="$default"
    fi
    
    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check if a shell is installed and available
shell_available() {
    local shell_name="$1"
    command_exists "$shell_name" && grep -q "$(command -v "$shell_name")" /etc/shells 2>/dev/null
}

# Get current default shell
get_current_shell() {
    basename "$SHELL"
}

# Check if a shell is already the default
is_default_shell() {
    local shell_name="$1"
    [ "$SHELL" = "$(command -v "$shell_name" 2>/dev/null)" ]
}

# Safely change default shell with user confirmation
change_default_shell() {
    local shell_name="$1"
    local shell_path
    
    if ! command_exists "$shell_name"; then
        log_error "$shell_name is not installed or not in PATH"
        return 1
    fi
    
    shell_path="$(command -v "$shell_name")"
    
    if is_default_shell "$shell_name"; then
        log_info "$shell_name is already your default shell"
        return 0
    fi
    
    # Add shell to /etc/shells if not already there
    if ! grep -q "$shell_path" /etc/shells 2>/dev/null; then
        log_step "Adding $shell_path to /etc/shells..."
        echo "$shell_path" | sudo tee -a /etc/shells >/dev/null
    fi
    
    log_step "To make $shell_name your default shell, please run:"
    echo "   chsh -s $shell_path"
    echo ""
    
    if confirm "Would you like to change your default shell to $shell_name now?" "y"; then
        if chsh -s "$shell_path"; then
            log_success "Default shell changed to $shell_name"
            log_info "Please restart your terminal or log out and back in for the change to take effect"
        else
            log_error "Failed to change default shell"
            return 1
        fi
    else
        log_info "Skipped changing default shell. You can run the chsh command later."
    fi
}

# Check if dotfiles setup has been run before
setup_already_run() {
    local marker_file="$HOME/.dotfiles_setup_complete"
    [ -f "$marker_file" ]
}

# Mark dotfiles setup as complete
mark_setup_complete() {
    local marker_file="$HOME/.dotfiles_setup_complete"
    echo "$(date)" > "$marker_file"
    log_debug "Marked setup as complete: $marker_file"
}

# Check if we're in a git repository
in_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
}

# Get git repository status
git_status() {
    if in_git_repo; then
        if [ -n "$(git status --porcelain)" ]; then
            echo "dirty"
        else
            echo "clean"
        fi
    else
        echo "not_a_repo"
    fi
}

# Install a command-line tool if not already present
ensure_tool_installed() {
    local tool_name="$1"
    local install_command="$2"
    
    if command_exists "$tool_name"; then
        log_debug "$tool_name already installed"
        return 0
    fi
    
    if [ -n "$install_command" ]; then
        log_step "Installing $tool_name..."
        eval "$install_command"
    else
        log_warning "$tool_name not found and no install command provided"
        return 1
    fi
}

# Wait for user input (useful for debugging)
wait_for_user() {
    local message="${1:-Press Enter to continue...}"
    read -p "$message" -r
}

# Display a separator line
separator() {
    echo "=================================================="
}

# Display a header with formatting
header() {
    local title="$1"
    echo ""
    separator
    echo "  $title"
    separator
    echo ""
}