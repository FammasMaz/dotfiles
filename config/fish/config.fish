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

# Oh My Posh (lazy load for better performance)
if command -v oh-my-posh >/dev/null 2>&1
    if test -f "$HOME/.dotfiles/themes/atomic.omp.json"
        # Cache oh-my-posh init to avoid repeated expensive calls
        set -l omp_cache_file "$HOME/.cache/oh-my-posh/fish-init.fish"
        set -l omp_config_file "$HOME/.dotfiles/themes/atomic.omp.json"
        
        # Check if cache exists and is newer than config
        if test -f "$omp_cache_file" -a "$omp_cache_file" -nt "$omp_config_file"
            source "$omp_cache_file" 2>/dev/null
            or echo "⚠️  Oh-my-posh cache corrupted, regenerating..."
        else
            # Generate and cache oh-my-posh init
            mkdir -p (dirname "$omp_cache_file")
            oh-my-posh init fish --config "$omp_config_file" > "$omp_cache_file" 2>/dev/null
            and source "$omp_cache_file" 2>/dev/null
            or echo "⚠️  Skipping oh-my-posh (requires newer fish version)"
        end
        
        # Fix for prompt disappearing after Ctrl+C
        function _fix_prompt_after_interrupt --on-signal SIGINT
            # Force prompt repaint after interrupt signal
            if functions -q _omp_new_prompt
                set -g _omp_new_prompt 1
            end
            # Trigger a new prompt
            commandline -f repaint
        end
        
        # Fallback prompt if oh-my-posh fails
        function _fallback_prompt
            set -l last_status $status
            set -l user (whoami)
            set -l hostname (hostname -s)
            set -l pwd_short (string replace -r "^$HOME" "~" (pwd))
            
            if test $last_status -eq 0
                echo -n "$user@$hostname:$pwd_short\$ "
            else
                echo -n "$user@$hostname:$pwd_short [$last_status]\$ "
            end
        end
        
        # Manual prompt recovery function (bind to Ctrl+P)
        function _recover_prompt
            if functions -q _omp_new_prompt
                set -g _omp_new_prompt 1
            end
            if functions -q _omp_current_prompt
                set -g _omp_current_prompt ""
            end
            if functions -q _omp_current_rprompt
                set -g _omp_current_rprompt ""
            end
            commandline -f repaint
        end
        
        # Bind Ctrl+P to recover prompt
        bind \cp _recover_prompt
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

# Lazy conda initialization - only init when conda command is used
function conda
    # Remove this function definition to prevent recursion
    functions -e conda
    
    # Initialize conda on first use
    set -l conda_path "/opt/homebrew/Caskroom/miniconda/base/bin/conda"
    if test -f "$conda_path"
        eval "$conda_path" "shell.fish" "hook" | source
    else
        # Fallback to PATH conda
        if command -v conda >/dev/null 2>&1
            set conda_path (command -v conda)
            eval "$conda_path" "shell.fish" "hook" | source
        else
            echo "conda not found"
            return 1
        end
    end
    
    # Call conda with original arguments
    conda $argv
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
