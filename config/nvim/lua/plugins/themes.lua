return {
	-- Builds the "terminal" colorscheme from the terminal's palette (colors/terminal.lua)
	{ "nvim-mini/mini.base16", lazy = true },
	-- Fallback when the terminal does not report its colors
	{ "neanias/everforest-nvim", lazy = true },
	{ "folke/tokyonight.nvim", lazy = true },
	{ "catppuccin/nvim", name = "catppuccin", lazy = true },
}
