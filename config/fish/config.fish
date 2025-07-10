# History settings
set -U fish_history_size 10000

# General options
set -g fish_greeting ""

# Environment variables
# Only add paths that exist to avoid warnings
if test -d "/opt/homebrew/bin"
    set -x PATH "/opt/homebrew/bin" $PATH
end
if test -d "$HOME/.local/bin"
    set -x PATH "$HOME/.local/bin" $PATH
end

# Aliases
# if macos use bat else batcat
if test (uname) = "Darwin"
    alias cat='bat'
else
    alias cat='batcat'
end
alias ghcp='gh copilot suggest'
alias lsa='eza -al --icons=always --color=always --sort=date'
alias df='duf'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ls='eza -al --icons=always --color=always --sort=date'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'

# Zoxide
if command -v zoxide >/dev/null 2>&1
    zoxide init fish --cmd cd | source
end

# Oh My Posh (skip on older fish versions to avoid syntax errors)
if command -v oh-my-posh >/dev/null 2>&1
    if test -f "$HOME/.dotfiles/themes/atomic.omp.json"
        # Try to load oh-my-posh, skip on syntax errors (older fish versions)
        oh-my-posh init fish --config "$HOME/.dotfiles/themes/atomic.omp.json" 2>/dev/null | source 2>/dev/null
        or echo "⚠️  Skipping oh-my-posh (requires newer fish version)"
    end
end

# OrbStack
if test -f ~/.orbstack/shell/init.fish
    source ~/.orbstack/shell/init.fish
end

# Environment Modules (common on HPC systems)
if test -f "/usr/share/Modules/init/fish"
    # Try to source the fish module init, but handle syntax errors gracefully
    if not source /usr/share/Modules/init/fish 2>/dev/null
        echo "⚠️  Environment Modules fish init has syntax errors, using bash fallback"
        # Fallback: create a wrapper function that calls module via bash
        function module
            bash -c "source /usr/share/Modules/init/bash && module $argv"
        end
    end
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
set -g conda_auto_activate_base false

# Cross-platform conda detection (in order of preference)
set -l conda_locations \
    "/opt/homebrew/Caskroom/miniconda/base/bin/conda" \
    "$HOME/miniconda3/bin/conda" \
    "$HOME/anaconda3/bin/conda" \
    "/usr/local/miniconda3/bin/conda" \
    "/usr/local/anaconda3/bin/conda"

set -l conda_path ""
set -l conda_base ""

# Find first available conda installation
for location in $conda_locations
    if test -f "$location"
        set conda_path "$location"
        set conda_base (dirname (dirname "$location"))
        break
    end
end

# If no specific installation found, try conda in PATH
if test -z "$conda_path"
    if command -v conda >/dev/null 2>&1
        set conda_path (command -v conda)
        set conda_base (dirname (dirname "$conda_path"))
    end
end

# Initialize conda if found
if test -n "$conda_path"
    eval "$conda_path" "shell.fish" "hook" $argv | source
else if test -f "$conda_base/etc/fish/conf.d/conda.fish"
    . "$conda_base/etc/fish/conf.d/conda.fish"
else if test -n "$conda_base"
    set -x PATH "$conda_base/bin" $PATH
end


# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
if test -f ~/.orbstack/shell/init2.fish
    source ~/.orbstack/shell/init2.fish 2>/dev/null
end

# --- Local & Machine-Specific Overrides ---
# For settings that should NOT be in git (secrets, machine-specific paths, work configs)
# Add .fish files to ~/.config/fish/local.d/
# Files load alphabetically - use prefixes like 01-paths.fish, 10-work.fish to control order
#
# Example: ~/.config/fish/local.d/01-python.fish
#   set -px PYTHONPATH /path/to/local/python/modules
#
set local_config_dir "$HOME/.config/fish/local.d"
if test -d "$local_config_dir"
    for file in "$local_config_dir"/*.fish
        if test -f "$file"
            source "$file"
        end
    end
end
