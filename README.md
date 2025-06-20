# Personal Dotfiles Configuration

A comprehensive dotfiles setup for macOS optimized for development productivity and aesthetics.

## 🚀 Quick Start

### macOS Setup (Recommended)
```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the macOS setup script
chmod +x macOS/setup.sh
./macOS/setup.sh
```

### Manual Linux Setup
```bash
# For Linux systems, use the zsh installation script
chmod +x zsh/install-zsh-setup.sh
./zsh/install-zsh-setup.sh
```

## 📦 What's Included

### 🐚 Zsh Configuration
- **Oh My Posh** with custom Atomic theme
- **Syntax highlighting** for better command visibility
- **Autosuggestions** for faster command completion
- **Zoxide** for smart directory navigation
- **Modern CLI tools**: `bat`, `eza`, `duf`, `thefuck`

### 🖥️ Terminal (Ghostty)
- **Theme**: Light (Material) / Dark (Vesper) with auto-switching
- **Font**: CaskaydiaMono Nerd Font Mono for proper icon rendering
- **Features**: Block cursor, shell integration, tabs-style titlebar

### 💻 VSCode/Cursor Configuration
- **Theme**: Vitesse Dark
- **Font**: Monaspace Neon with ligatures enabled
- **Terminal**: Ghostty integration
- **Python**: Ruff formatter with 119 character line length
- **LaTeX**: Workshop configuration with custom output directory
- **Remote SSH**: Optimized connection settings

### 🔧 Development Tools
- **GitHub CLI** with authentication setup
- **Conda/Miniconda** environment management
- **Git aliases** for common operations
- **Custom file exclusions** for cleaner workspace

## 📁 Directory Structure

```
dotfiles/
├── README.md                    # This file
├── VSCode/
│   └── settings.json           # VSCode/Cursor settings
├── ghostty/
│   └── config                  # Ghostty terminal configuration
├── macOS/
│   └── setup.sh               # Automated macOS setup script
└── zsh/
    ├── atomic.omp.json        # Custom Oh My Posh theme
    └── install-zsh-setup.sh   # Linux zsh installation script
```

## ⚙️ Configuration Details

### Zsh Features
- **History**: 10,000 commands with deduplication
- **Auto-completion**: Enhanced with context-aware suggestions
- **Navigation**: `z` command for quick directory jumping
- **Aliases**: Git shortcuts and improved `ls` commands
- **Theme**: Custom Atomic theme with:
  - Shell indicator
  - Current path with folder icons
  - Git status with branch and changes
  - Execution time for long-running commands
  - Language-specific version indicators (Python, Node, Java, etc.)
  - System information (OS, battery, time)

### VSCode/Cursor Optimizations
- **Performance**: GPU acceleration disabled for stability
- **UI**: Minimal layout with right sidebar placement
- **Editor**: Smooth scrolling, underline cursor, optimized padding
- **Remote Development**: SSH configuration with timeout settings
- **Language Support**: 
  - Python with Ruff formatting
  - LaTeX with ChkTeX linting
  - GitHub Copilot integration (selective)

### Ghostty Terminal
- **Adaptive theming** based on system appearance
- **Font rendering** optimized for coding
- **Shell integration** with zsh for enhanced features
- **Window management** with proper sizing defaults

## 🛠️ Manual Configuration Steps

### After Installation

1. **Restart your terminal** or run `source ~/.zshrc`
2. **Authenticate GitHub CLI**: `gh auth login`
3. **Enable Copilot** (optional): `gh extension install github/gh-copilot`
4. **Install VSCode extensions** as needed
5. **Configure Git**:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

### Font Installation
The setup script installs CaskaydiaMono Nerd Font, but if you need additional fonts:
```bash
brew install --cask font-cascadia-code-pl
brew install --cask font-monaspace
```

## 🎨 Customization

### Changing Oh My Posh Theme
```bash
# List available themes
oh-my-posh get themes

# Use a different theme
oh-my-posh init zsh --config ~/.cache/oh-my-posh/themes/<theme-name>.omp.json
```

### Modifying Zsh Configuration
Edit `~/.zshrc` to add custom aliases, functions, or environment variables.

### VSCode Settings Sync
Enable Settings Sync in VSCode to synchronize across devices, or manually copy `VSCode/settings.json` to your VSCode settings directory.

## 🔍 Troubleshooting

### Command Not Found Errors
```bash
# Reload shell configuration
source ~/.zshrc

# Check PATH
echo $PATH

# Reinstall homebrew packages
brew doctor && brew update
```

### Oh My Posh Theme Issues
```bash
# Reinstall oh-my-posh
brew reinstall oh-my-posh

# Verify theme file exists
ls ~/.cache/oh-my-posh/themes/atomic.omp.json
```

### Font Rendering Problems
- Ensure terminal is using a Nerd Font
- Check font installation: `brew list --cask | grep font`
- Restart terminal application after font changes

## 📋 Dependencies

### Installed via Homebrew
- `bat` - Better cat with syntax highlighting
- `eza` - Modern ls replacement
- `duf` - Better df with disk usage visualization
- `zoxide` - Smarter cd command
- `thefuck` - Command correction tool
- `gh` - GitHub CLI
- `oh-my-posh` - Prompt theme engine

### Zsh Plugins
- `zsh-autosuggestions` - Command suggestions
- `zsh-syntax-highlighting` - Syntax highlighting

## 🤝 Contributing

Feel free to fork this repository and customize it for your own needs. If you have improvements or bug fixes, pull requests are welcome!

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

**Note**: This configuration is optimized for macOS development workflows but includes Linux compatibility scripts. Some features may require adjustment for different environments.