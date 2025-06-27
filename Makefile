SHELL := /bin/bash

# Get the directory where this Makefile is located
DOTFILES_DIR := $(shell pwd)

.PHONY: help zsh fish linux

help:
	@echo "Please use \`make <target>\` where <target> is one of the following:"
	@echo "  zsh    - installs the zsh configuration (macOS)"
	@echo "  fish   - installs the fish shell configuration"
	@echo "  linux  - installs the linux configuration"

zsh:
	@echo "Installing zsh configuration..."
	@cd $(DOTFILES_DIR) && ./macOS/setup.sh

linux:
	@echo "Installing linux configuration..."
	@cd $(DOTFILES_DIR) && ./linuxOS/setup.sh

fish:
	@echo "Installing fish shell configuration..."
	@cd $(DOTFILES_DIR) && ./fishOS/fish/setup.sh
