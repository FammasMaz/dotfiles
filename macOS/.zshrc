HISTSIZE=10000        # Number of commands in the current session
SAVEHIST=10000        # Number of commands to save to .zsh_history
HISTFILE=~/.zsh_history  # Path to the history file
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE

# General options
setopt AUTO_CD
setopt CORRECT
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END

export PATH="/opt/homebrew/bin:$PATH"

# Cache brew prefix to avoid multiple calls
BREW_PREFIX="/opt/homebrew"

alias cat='bat'
alias ghcp='gh copilot suggest'
alias lsa='eza -al --icons=always --color=always --sort=date'
alias df='duf'

# some other shit
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

# Defer expensive initializations - only run when needed
# Zoxide (fast directory jumping)
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# Oh-my-posh prompt (most expensive - consider alternatives)
if command -v oh-my-posh >/dev/null 2>&1; then
    eval "$(oh-my-posh init zsh --config "${BREW_PREFIX}/opt/oh-my-posh/themes/atomic.omp.json")"
fi

# Zsh plugins with cached paths
if [[ -f "${BREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "${BREW_PREFIX}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

if [[ -f "${BREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "${BREW_PREFIX}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

if [[ -d /opt/homebrew/share/zsh/site-functions ]]; then
    fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fi

autoload -Uz compinit
compinit -u

# Lazy load thefuck and gh copilot (only when first used)
fuck() {
    if ! command -v thefuck >/dev/null 2>&1; then
        echo "thefuck not found"
        return 1
    fi
    eval "$(thefuck --alias)"
    fuck "$@"
}

# Lazy load gh copilot
ghcs() {
    if ! command -v gh >/dev/null 2>&1; then
        echo "gh not found"
        return 1
    fi
    eval "$(gh copilot alias -- zsh)"
    ghcs "$@"
}

# Conda initialization (optimized)
__conda_setup="$('/Users/fammasmaz/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/fammasmaz/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/fammasmaz/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/fammasmaz/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
