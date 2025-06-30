SHELL := /bin/bash

# Get the directory where this Makefile is located
DOTFILES_DIR := $(shell pwd)

.PHONY: help install update fish zsh clean

help:
	@echo "Universal Dotfiles Setup"
	@echo "========================"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  install     - Run universal dotfiles installation (recommended)"
	@echo "  update      - Update repository and reinstall"
	@echo "  fish        - Setup Fish shell specifically"
	@echo "  zsh         - Setup Zsh shell specifically"
	@echo "  clean       - Remove setup marker (forces full reinstall)"
	@echo ""
	@echo "For more options, run: ./setup.sh --help"

install:
	@echo "🚀 Running universal dotfiles installation..."
	@cd $(DOTFILES_DIR) && ./setup.sh

update:
	@echo "🔄 Updating repository and reinstalling..."
	@git pull --ff-only
	@cd $(DOTFILES_DIR) && ./setup.sh

fish:
	@echo "🐠 Setting up Fish shell..."
	@cd $(DOTFILES_DIR) && ./install/shell.sh fish

zsh:
	@echo "🐚 Setting up Zsh shell..."
	@cd $(DOTFILES_DIR) && ./install/shell.sh zsh

clean:
	@echo "🧹 Cleaning up setup markers..."
	@rm -f ~/.dotfiles_setup_complete
	@echo "Setup markers removed. Next 'make install' will run full setup."

# Legacy targets for backwards compatibility
mac: install
linux: install
server: install

.DEFAULT_GOAL := help