# Universal Dotfiles

Streamlined, cross-platform dotfiles setup with Fish shell priority and Zsh compatibility.

## Quick Start

```bash
# Single command setup
make install

# Or run directly
./setup.sh
```

## Features

- 🐠 **Fish shell preferred** with Zsh fallback
- 🖥️ **Cross-platform**: macOS & Linux support
- 📦 **Smart package management** with OS detection
- 🔄 **Idempotent**: Safe to run multiple times
- 🎨 **Oh My Posh** themes included
- ⚡ **Modern tools**: bat, eza, zoxide, fzf, etc.

## Directory Structure

```
.
├── setup.sh                # Universal entry point
├── Makefile                # Simple targets (install, update, etc.)
│
├── lib/                    # Core libraries
│   ├── os_detect.sh        # OS & package manager detection
│   └── utils.sh           # Helper functions & logging
│
├── install/               # Installation scripts
│   ├── packages.sh        # Package installation
│   ├── shell.sh          # Shell configuration
│   ├── packages.common   # Common packages
│   ├── packages.macos    # macOS-specific packages
│   └── packages.linux_*  # Linux distribution packages
│
└── config/               # Configuration files
    ├── fish/            # Fish shell configs
    ├── zsh/             # Zsh configs  
    └── shared/          # Shared configs (git, themes, etc.)
```

## Usage

### Standard Installation
```bash
make install        # Full setup with Fish preferred
./setup.sh         # Same as above
```

### Shell-Specific Setup
```bash
make fish          # Setup Fish shell only
make zsh           # Setup Zsh only
```

### Maintenance
```bash
make update        # Update repo and reinstall
make clean         # Reset setup state
```

### Debug Mode
```bash
./setup.sh --debug
```

## What Gets Installed

### Common Tools
- **Shells**: fish, zsh
- **Modern CLI**: bat, eza, duf, zoxide, fzf
- **Development**: git, gh, neovim
- **System**: curl, wget, tree, htop

### macOS Additions
- Homebrew (if not present)
- Miniconda
- Zsh plugins via Homebrew

### Linux Additions  
- Build tools (gcc, make)
- Development libraries
- Distribution-specific packages

## Shell Configuration

### Fish (Preferred)
- Modern shell with excellent defaults
- Fisher plugin manager
- Smart command completion
- Zsh history migration

### Zsh (Fallback)
- Cross-platform compatibility
- Oh My Zsh alternatives
- Manual plugin management
- Performance optimizations

## Application Configurations

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

## Customization

### Adding Packages
Edit the appropriate package file:
- `install/packages.common` - All platforms
- `install/packages.macos` - macOS only  
- `install/packages.linux_*` - Linux distributions

### Shell Configs
- Fish: `config/fish/config.fish`
- Zsh: `config/zsh/.zshrc`
- Shared: `config/shared/`

### Themes
Oh My Posh themes in `config/shared/themes/`

## Post-Installation Steps

1. **Restart your terminal** or run `exec $SHELL`
2. **Authenticate GitHub CLI**: `gh auth login`
3. **Enable Copilot** (optional): `gh extension install github/gh-copilot`
4. **Configure Git**:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

## Troubleshooting

### Permission Issues
```bash
# Make scripts executable
chmod +x setup.sh install/*.sh
```

### Package Manager Issues
```bash
# Debug package manager detection
./setup.sh --debug
```

### Reset Everything
```bash
make clean
make install
```

### Command Not Found Errors
```bash
# Reload shell configuration
exec $SHELL

# Check PATH
echo $PATH

# Reinstall packages
make update
```

## Migration from Old Structure

The new structure replaces:
- `fishOS/` → `config/fish/` + `install/shell.sh`
- `macOS/` → `install/packages.sh` + universal detection
- `linuxOS/` → `install/packages.sh` + distribution-specific lists
- `zsh/` → `config/zsh/` + `install/shell.sh`

Legacy Makefile targets (`mac`, `linux`, `server`) redirect to `make install`.

## Contributing

1. Test changes on both macOS and Linux
2. Maintain backwards compatibility for existing users
3. Follow the concern-based directory structure
4. Update package lists rather than hardcoding in scripts

---

**Previous Version**: See legacy setup in `fishOS/`, `macOS/`, `linuxOS/`, and `zsh/` directories (deprecated).