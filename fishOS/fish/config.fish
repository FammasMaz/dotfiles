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
    set -x STARSHIP_CONFIG "$HOME/.config/starship/starship.toml"
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
