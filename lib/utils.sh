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

# Conda migration functions
backup_conda_environments() {
    local backup_dir="$1"
    local conda_path="$2"
    
    log_step "Backing up conda environments to $backup_dir..."
    mkdir -p "$backup_dir"
    
    # Get list of environments (excluding base and directories with spaces)
    local env_list
    env_list=$("$conda_path" env list 2>/dev/null | grep -v "^#" | awk 'NF>1 {print $1}' | grep -v "base")
    
    if [ -z "$env_list" ]; then
        log_info "No custom environments found to backup"
        return 0
    fi
    
    echo "$env_list" | while read -r env_name; do
        if [ -n "$env_name" ]; then
            log_info "Backing up environment: $env_name"
            
            # Export environment.yml
            if "$conda_path" env export -n "$env_name" > "$backup_dir/${env_name}.yml" 2>/dev/null; then
                log_debug "Exported $env_name.yml"
            else
                log_warning "Failed to export $env_name.yml"
            fi
            
            # Export explicit spec list for exact reproduction
            if "$conda_path" list --explicit -n "$env_name" > "$backup_dir/${env_name}.spec.txt" 2>/dev/null; then
                log_debug "Exported $env_name.spec.txt"
            else
                log_warning "Failed to export $env_name.spec.txt"
            fi
        fi
    done
    
    log_success "Environment backup completed"
}

restore_conda_environments() {
    local backup_dir="$1"
    local conda_path="$2"
    
    log_step "Restoring conda environments from $backup_dir..."
    
    # Set up logging directory
    local log_dir="$backup_dir/logs"
    mkdir -p "$log_dir"
    
    # Detect timeout command
    local timeout_cmd
    timeout_cmd=$(find_timeout_command)
    if [ -z "$timeout_cmd" ]; then
        log_warning "Timeout command not found. Conda operations may hang indefinitely."
        log_warning "On macOS, install with: brew install coreutils"
    fi
    
    # Configuration
    local conda_timeout_seconds=1800  # 30 minutes
    
    # Find all .spec.txt files (prioritize exact restoration)
    local environments_restored=0
    local environments_failed=0
    
    for spec_file in "$backup_dir"/*.spec.txt; do
        if [ -f "$spec_file" ]; then
            local env_name
            env_name=$(basename "$spec_file" .spec.txt)
            
            restore_single_environment "$backup_dir" "$conda_path" "$env_name" "$log_dir" "$timeout_cmd" "$conda_timeout_seconds"
            
            if [ $? -eq 0 ]; then
                ((environments_restored++))
            else
                ((environments_failed++))
            fi
        fi
    done
    
    # Summary
    echo ""
    log_success "Environment restoration completed"
    log_info "Restored: $environments_restored environments"
    if [ $environments_failed -gt 0 ]; then
        log_warning "Failed: $environments_failed environments"
        log_info "Check logs in: $log_dir"
    fi
}

# Helper function to find timeout command
find_timeout_command() {
    if command -v gtimeout &> /dev/null; then
        echo "gtimeout"
    elif command -v timeout &> /dev/null; then
        echo "timeout"
    else
        echo ""
    fi
}

# Restore a single environment with three-tier strategy
restore_single_environment() {
    local backup_dir="$1"
    local conda_path="$2"
    local env_name="$3"
    local log_dir="$4"
    local timeout_cmd="$5"
    local timeout_seconds="$6"
    
    local spec_file="$backup_dir/${env_name}.spec.txt"
    local yml_file="$backup_dir/${env_name}.yml"
    local restoration_log="$log_dir/${env_name}-restore.log"
    
    log_info "Restoring environment: $env_name"
    log_debug "Progress logged to: $restoration_log"
    
    # Clear previous log
    > "$restoration_log"
    
    # Tier 1: Restore from spec.txt (most precise)
    if restore_from_spec_file "$conda_path" "$env_name" "$spec_file" "$restoration_log" "$timeout_cmd" "$timeout_seconds"; then
        log_success "Restored $env_name from spec file (exact versions)"
        validate_environment "$conda_path" "$env_name"
        return 0
    fi
    
    # Tier 2: Restore from environment.yml (flexible versions)
    if [ -f "$yml_file" ]; then
        if restore_from_yml_file "$conda_path" "$yml_file" "$restoration_log" "$timeout_cmd" "$timeout_seconds"; then
            log_success "Restored $env_name from environment.yml (compatible versions)"
            validate_environment "$conda_path" "$env_name"
            return 0
        fi
    fi
    
    # Tier 3: Restore with flexible versions (last resort)
    if restore_with_flexible_versions "$conda_path" "$env_name" "$yml_file" "$restoration_log" "$timeout_cmd" "$timeout_seconds"; then
        log_success "Restored $env_name with flexible versions (versions may differ)"
        log_warning "⚠️  Package versions in $env_name may differ from the original"
        validate_environment "$conda_path" "$env_name"
        return 0
    fi
    
    # All tiers failed
    log_error "Failed to restore $env_name from all available methods"
    log_error "Manual restoration may be needed. Check: $restoration_log"
    return 1
}

# Tier 1: Restore from spec file
restore_from_spec_file() {
    local conda_path="$1"
    local env_name="$2"
    local spec_file="$3"
    local log_file="$4"
    local timeout_cmd="$5"
    local timeout_seconds="$6"
    
    if [ ! -f "$spec_file" ]; then
        return 1
    fi
    
    log_debug "Attempting spec file restoration for $env_name..."
    echo "=== Tier 1: Spec file restoration ===" >> "$log_file"
    
    if [ -n "$timeout_cmd" ]; then
        "$timeout_cmd" "$timeout_seconds" "$conda_path" create --name "$env_name" --file "$spec_file" --yes 2>&1 | tee -a "$log_file"
    else
        "$conda_path" create --name "$env_name" --file "$spec_file" --yes 2>&1 | tee -a "$log_file"
    fi
}

# Tier 2: Restore from environment.yml
restore_from_yml_file() {
    local conda_path="$1"
    local yml_file="$2"
    local log_file="$3"
    local timeout_cmd="$4"
    local timeout_seconds="$5"
    
    log_debug "Attempting environment.yml restoration..."
    echo "=== Tier 2: Environment.yml restoration ===" >> "$log_file"
    
    if [ -n "$timeout_cmd" ]; then
        "$timeout_cmd" "$timeout_seconds" "$conda_path" env create -f "$yml_file" --yes 2>&1 | tee -a "$log_file"
    else
        "$conda_path" env create -f "$yml_file" --yes 2>&1 | tee -a "$log_file"
    fi
}

# Tier 3: Restore with flexible versions
restore_with_flexible_versions() {
    local conda_path="$1"
    local env_name="$2"
    local yml_file="$3"
    local log_file="$4"
    local timeout_cmd="$5"
    local timeout_seconds="$6"
    
    if [ ! -f "$yml_file" ]; then
        return 1
    fi
    
    log_debug "Attempting flexible version restoration for $env_name..."
    echo "=== Tier 3: Flexible version restoration ===" >> "$log_file"
    
    # Create flexible yml by removing version constraints
    local flexible_yml="/tmp/${env_name}_flexible.yml"
    create_flexible_yml "$yml_file" "$flexible_yml"
    
    if [ -n "$timeout_cmd" ]; then
        "$timeout_cmd" "$timeout_seconds" "$conda_path" env create -f "$flexible_yml" --yes 2>&1 | tee -a "$log_file"
    else
        "$conda_path" env create -f "$flexible_yml" --yes 2>&1 | tee -a "$log_file"
    fi
    
    # Cleanup
    rm -f "$flexible_yml"
}

# Create a flexible environment.yml with version constraints removed
create_flexible_yml() {
    local original_yml="$1"
    local flexible_yml="$2"
    
    # Copy the header and remove version constraints from dependencies
    awk '
    /^dependencies:/ { in_deps = 1 }
    in_deps && /^  - / { 
        # Remove version constraints (everything after = or >)
        gsub(/[>=<].*/, "")
        print
        next
    }
    !in_deps || !/^  - / { 
        if (!/^  - /) in_deps = 0
        print 
    }
    ' "$original_yml" > "$flexible_yml"
}

# Validate a restored environment
validate_environment() {
    local conda_path="$1"
    local env_name="$2"
    
    log_debug "Validating environment: $env_name"
    
    # Test if environment exists and has basic functionality
    if "$conda_path" run -n "$env_name" python --version >/dev/null 2>&1; then
        log_debug "✓ $env_name validation successful (Python available)"
    elif "$conda_path" run -n "$env_name" echo "test" >/dev/null 2>&1; then
        log_debug "✓ $env_name validation successful (environment functional)"
    else
        log_warning "⚠️  $env_name validation failed - environment may be broken"
    fi
}

prompt_conda_migration() {
    local conda_path="$1"
    
    log_warning "Found existing conda installation at: $conda_path"
    echo ""
    echo "This script can install miniconda via Homebrew for unified package management."
    echo "What would you like to do?"
    echo ""
    echo "1. Skip - Keep your existing installation (recommended if unsure)"
    echo "2. Migrate - Backup environments, install via Homebrew, restore environments"  
    echo "3. Abort - Stop the script to investigate manually"
    echo ""
    
    while true; do
        read -p "Please choose [1/2/3]: " -r choice
        case $choice in
            1)
                log_info "Keeping existing conda installation"
                return 1  # Skip installation
                ;;
            2)
                log_info "Proceeding with conda migration"
                return 0  # Proceed with migration
                ;;
            3)
                log_info "Aborting script"
                exit 0
                ;;
            *)
                echo "Please enter 1, 2, or 3"
                ;;
        esac
    done
}

migrate_conda_installation() {
    local old_conda_path="$1"
    local package_manager_install_cmd="$2"
    
    # Create backup directory
    local backup_dir
    backup_dir="$HOME/conda_backup_$(date +%Y%m%d_%H%M%S)"
    
    log_step "Starting conda migration process..."
    
    # Backup environments
    backup_conda_environments "$backup_dir" "$old_conda_path"
    
    # Detect old conda installation directory
    local old_conda_dir
    old_conda_dir=$(dirname "$(dirname "$old_conda_path")")  # Remove /bin/conda
    
    if [ -d "$old_conda_dir" ]; then
        # Rename old installation as backup
        local backup_conda_dir="${old_conda_dir}.bak.$(date +%Y%m%d_%H%M%S)"
        log_step "Backing up old conda installation to $backup_conda_dir"
        
        if mv "$old_conda_dir" "$backup_conda_dir" 2>/dev/null; then
            log_success "Old conda installation backed up"
        else
            log_warning "Could not move old conda installation. It may still be accessible."
        fi
    fi
    
    # Install new conda via package manager
    log_step "Installing miniconda via package manager..."
    if eval "$package_manager_install_cmd miniconda"; then
        log_success "Miniconda installed via package manager"
    else
        log_error "Failed to install miniconda via package manager"
        return 1
    fi
    
    # Find new conda installation
    local new_conda_path
    new_conda_path=$(command -v conda 2>/dev/null)
    
    if [ -z "$new_conda_path" ]; then
        log_error "New conda installation not found in PATH"
        return 1
    fi
    
    # Restore environments
    restore_conda_environments "$backup_dir" "$new_conda_path"
    
    # Final instructions
    echo ""
    log_success "Conda migration completed!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Test your environments: conda activate <env_name>"
    echo "2. If everything works, you can safely remove:"
    echo "   - Backup directory: $backup_dir"
    if [ -n "${backup_conda_dir:-}" ]; then
        echo "   - Old installation: $backup_conda_dir"
    fi
    echo "3. Update your shell configuration if needed"
    echo ""
}