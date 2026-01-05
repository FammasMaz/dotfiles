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

if status is-interactive
    and not set -q CLAUDECODE
    and command -v zoxide >/dev/null 2>&1
    zoxide init fish --cmd cd | source
end

# Atuin history sync
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
if test -f ~/.orbstack/shell/init2.fish
    source ~/.orbstack/shell/init2.fish 2>/dev/null
end

# Title functions for terminal window titles
function __title_join --description "join args with bullet"
    set -l out
    for a in $argv
        test -n "$a"; and set out $out $a
    end
    echo (string join " • " $out)
end

function __title_git
    command -q git; or return
    git rev-parse --is-inside-work-tree >/dev/null 2>&1; or return
    set -l branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null); or set branch (command git describe --tags --always 2>/dev/null)
    test -n "$branch"; and echo "git:$branch"
end

function __title_k8s
    command -q kubectl; or return
    set -l ctx (kubectl config current-context 2>/dev/null); or return
    set -l ns (kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
    test -n "$ns"; and echo "k8s:$ctx:$ns"; or echo "k8s:$ctx"
end

function __title_aws
    if set -q AWS_PROFILE
        if set -q AWS_REGION
            echo "aws:$AWS_PROFILE@$AWS_REGION"
        else if set -q AWS_DEFAULT_REGION
            echo "aws:$AWS_PROFILE@$AWS_DEFAULT_REGION"
        else
            echo "aws:$AWS_PROFILE"
        end
    end
end

function fish_title
    set -l cmd
    if set -q argv[1]
        set -l raw (string trim -- $argv[1])
        set -l words (string split --no-empty ' ' -- $raw)
        set -l sudo_opts_with_arg -u --user -g --group -h --host -p --prompt -C --close-from -D --chdir -r --role -t --type -U --other-user
        set -l in_sudo 0
        set -l skip_next 0
        for word in $words
            if test $skip_next -eq 1
                set skip_next 0
                continue
            end
            if test $in_sudo -eq 0
                if test "$word" = "sudo"
                    set in_sudo 1
                    continue
                end
                set cmd $word
                break
            else
                if test "$word" = "--"
                    set in_sudo 0
                    continue
                end
                if string match -qr '^-[ugCDrtUp].+' -- $word
                    continue
                end
                if string match -qr '^--(user|group|host|prompt|close-from|chdir|role|type|other-user)=' -- $word
                    continue
                end
                if contains -- $word $sudo_opts_with_arg
                    set skip_next 1
                    continue
                end
                if string match -qr '^-' -- $word
                    continue
                end
                set cmd $word
                break
            end
        end
        if test -z "$cmd"
            and test (count $words) -gt 0
            set cmd $words[1]
        end
    end
    set -l where (prompt_pwd)                              # ~/…/dir
    set -l hostseg
    # Check for SSH connection using multiple methods
    if set -q SSH_TTY; or set -q SSH_CLIENT; or set -q SSH_CONNECTION
        set hostseg (whoami)"@"(hostname -s)
    end
    set -l tmuxseg
    if set -q TMUX
        set tmuxseg "tmux:"(tmux display-message -p '#S' 2>/dev/null)
    end
    set -l sudoseg
    if set -q SUDO_USER
        set sudoseg "sudo:"$SUDO_USER
    end
    __title_join $cmd $hostseg $tmuxseg $sudoseg (__title_git) (__title_k8s) (__title_aws) $where
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
# AGENTS
alias opencode="bunx opencode-ai@latest"
alias opencode-tui="bunx opencode-ai@opentui"
alias codex="bunx @openai/codex@latest"
alias ccusage="bunx ccusage@latest"
alias codexusage="bunx @ccusage/codex@latest"
# alias gemini="bunx @google/gemini-cli@latest"
alias copilot="bunx @github/copilot@latest"
alias cursor-cli="cursor-agent update && cursor-agent"
alias uwu="uwu-cli"
alias crush="bunx @charmland/crush@latest"


fish_add_path $HOME/.cargo/bin
export OPENCODE_DISABLE_DEFAULT_PLUGINS=1

# bunx
fish_add_path $HOME/.bun/bin
