# History settings
set -U fish_history_size 10000

# General options
set -g fish_greeting ""

# Environment variables
set -x PATH "/opt/homebrew/bin" $PATH

# Aliases
alias cat='bat'
alias ghcp='gh copilot suggest'
alias lsa='eza -al --icons=always --color=always --sort=date'
alias df='duf'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias cd='z'

# Zoxide
if command -v zoxide >/dev/null 2>&1
    zoxide init fish | source
end

# Oh My Posh
if command -v oh-my-posh >/dev/null 2>&1
    oh-my-posh init fish --config "/opt/homebrew/opt/oh-my-posh/themes/atomic.omp.json" | source
end

# OrbStack
if test -f ~/.orbstack/shell/init.fish
    source ~/.orbstack/shell/init.fish
end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
set -g conda_auto_activate_base false
if test -f /Users/fammasmaz/miniconda3/bin/conda
    eval /Users/fammasmaz/miniconda3/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "/Users/fammasmaz/miniconda3/etc/fish/conf.d/conda.fish"
        . "/Users/fammasmaz/miniconda3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/Users/fammasmaz/miniconda3/bin" $PATH
    end
end
# <<< conda initialize <<<

