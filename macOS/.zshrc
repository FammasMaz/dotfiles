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

alias cat='bat'
alias ghcp='gh copilot suggest'
alias lsa='eza -al --icons=always --color=always --sort=date'
alias df='duf'

# Additional tools
eval "$(zoxide init zsh)"
eval "$(thefuck --alias)"
eval "$(gh copilot alias -- zsh)"

source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval "$(oh-my-posh init zsh --config "/opt/homebrew/opt/oh-my-posh/themes/atomic.omp.json")"

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
