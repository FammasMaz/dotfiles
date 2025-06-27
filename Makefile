SHELL := /bin/bash

.PHONY: help zsh fish

help:
	@echo "Please use `make <target>` where <target> is one of the following:"
	@echo "  zsh    - installs the zsh configuration"
	@echo "  fish   - installs the fish shell configuration"
	@echo "  linux  - installs the linux configuration"

zsh:
	@echo "Installing zsh configuration..."
	@./macOS/setup.sh

linux:
	@echo "Installing linux configuration..."
	@./linuxOS/setup.sh

fish:
	@echo "Installing fish shell configuration..."
	@./fishOS/fish/setup.sh
