# Zsh Configuration
# Universal configuration for Fish/Zsh compatibility

# History settings
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
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

# PATH configuration
export PATH="$HOME/.local/bin:$PATH"

# macOS Homebrew paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Detect Homebrew location (Intel vs Apple Silicon)
    if [[ -d "/opt/homebrew" ]]; then
        export PATH="/opt/homebrew/bin:$PATH"
        BREW_PREFIX="/opt/homebrew"
    elif [[ -d "/usr/local/Homebrew" ]]; then
        export PATH="/usr/local/bin:$PATH"
        BREW_PREFIX="/usr/local"
    fi
fi

# Aliases - keep in sync with fish config concepts
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias cat='bat'
else
    alias cat='batcat'  # Linux package name
fi

alias ghcp='gh copilot suggest'
alias lsa='eza -al --icons=always --color=always --sort=date'
alias ls='eza -al --icons=always --color=always --sort=date'
alias df='duf'

# Basic aliases
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

# Initialize zoxide for smart cd
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd cd)"
fi

# Oh-my-posh prompt
if command -v oh-my-posh >/dev/null 2>&1; then
    eval "$(oh-my-posh init zsh --config "$HOME/.dotfiles/themes/atomic.omp.json")"
fi

# Zsh plugins - try multiple locations for cross-platform compatibility
load_zsh_plugin() {
    local plugin_name="$1"
    local locations=(
        "${BREW_PREFIX}/share/${plugin_name}/${plugin_name}.zsh"  # Homebrew
        "/usr/share/${plugin_name}/${plugin_name}.zsh"           # System package
        "$HOME/.zsh/plugins/${plugin_name}/${plugin_name}.zsh"   # Manual install
    )
    
    for location in "${locations[@]}"; do
        if [[ -f "$location" ]]; then
            source "$location"
            return 0
        fi
    done
    return 1
}

# Load zsh-autosuggestions
if load_zsh_plugin "zsh-autosuggestions"; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# Load zsh-syntax-highlighting (must be loaded last)
load_zsh_plugin "zsh-syntax-highlighting"

# Completion setup
if [[ -d "${BREW_PREFIX}/share/zsh/site-functions" ]]; then
    fpath=("${BREW_PREFIX}/share/zsh/site-functions" $fpath)
fi

autoload -Uz compinit
compinit -u

# Lazy load thefuck
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

# Cross-platform conda initialization
# Try conda locations in order of preference
conda_locations=(
    "/opt/homebrew/Caskroom/miniconda/base/bin/conda"  # Homebrew macOS
    "$HOME/miniconda3/bin/conda"                       # Standard miniconda
    "$HOME/anaconda3/bin/conda"                        # Standard anaconda
    "/usr/local/miniconda3/bin/conda"                  # System miniconda
    "/usr/local/anaconda3/bin/conda"                   # System anaconda
)

conda_path=""
conda_base=""

# Find first available conda installation
for location in "${conda_locations[@]}"; do
    if [[ -f "$location" ]]; then
        conda_path="$location"
        conda_base="$(dirname "$(dirname "$location")")"
        break
    fi
done

# If no specific installation found, try conda in PATH
if [[ -z "$conda_path" ]] && command -v conda >/dev/null 2>&1; then
    conda_path="$(command -v conda)"
    conda_base="$(dirname "$(dirname "$conda_path")")"
fi

# Initialize conda if found
if [[ -n "$conda_path" ]]; then
    __conda_setup="$('$conda_path' 'shell.zsh' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "$conda_base/etc/profile.d/conda.sh" ]; then
            . "$conda_base/etc/profile.d/conda.sh"
        else
            export PATH="$conda_base/bin:$PATH"
        fi
    fi
    unset __conda_setup
fi
unset conda_locations conda_path conda_base

# Better history search
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Load additional local configurations if they exist
if [[ -f "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi