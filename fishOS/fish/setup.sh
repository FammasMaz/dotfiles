#!/bin/bash

# Install fish if not already installed
if ! command -v fish &> /dev/null
then
    echo "fish could not be found, installing..."
    brew install fish
fi

# Set fish as the default shell
if [ "$SHELL" != "/opt/homebrew/bin/fish" ]
then
    echo "Setting fish as the default shell..."
    chsh -s /opt/homebrew/bin/fish
fi

# Install fisher, the fish plugin manager
if ! fish -c "type -q fisher"
then
    echo "Installing fisher..."
    fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher"
fi

# Install plugins
fish -c "fisher install jethrokuan/z"
fish -c "fisher install PatrickF1/fzf.fish"

# Symlink the config.fish file
ln -sf "/Users/fammasmaz/Documents/dotfiles/fishOS/fish/config.fish" "$HOME/.config/fish/config.fish"
# download git clone https://github.com/thenktor/zsh-history-to-fish.git and use the script to convert the history to fish
# only if zsh_history exists
if [ -f "$HOME/.zsh_history" ]
then
    git clone https://github.com/thenktor/zsh-history-to-fish.git
    cd zsh-history-to-fish
    # empty the fish_history file
    > "$HOME/.local/share/fish/fish_history"
    ./zsh-fish.sh -i "$HOME/.zsh_history" -o "$HOME/.local/share/fish/fish_history"
    cd ..
    rm -rf zsh-history-to-fish
fi
echo "Fish shell setup complete!"
