# History settings
set -U fish_history_size 10000

# General options
set -g fish_greeting ""

# Environment variables
set -x PATH "/opt/homebrew/bin" $PATH
set -x PATH "$HOME/.local/bin" $PATH

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

if command -v atuin >/dev/null 2>&1
    atuin init fish | source
end

# Starship prompt
if command -v starship >/dev/null 2>&1
    set -l starship_template "$HOME/.config/starship/starship.toml"
    set -l starship_generated "$HOME/.cache/starship/starship.ghostty.toml"
    set -l starship_sync_script "$HOME/.dotfiles/lib/sync_starship_ghostty_palette.py"

    if command -v python3 >/dev/null 2>&1
        and test -f "$starship_sync_script"
        python3 "$starship_sync_script" --template "$starship_template" --output "$starship_generated" >/dev/null 2>&1
    end

    if test -f "$starship_generated"
        set -x STARSHIP_CONFIG "$starship_generated"
    else
        set -x STARSHIP_CONFIG "$starship_template"
    end

    starship init fish | source
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

# uv for Python package management
if command -v uv >/dev/null 2>&1
    # Add uv completions if available
    if test -f "$HOME/.local/share/uv/completion/uv.fish"
        source "$HOME/.local/share/uv/completion/uv.fish"
    end
end


# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :
