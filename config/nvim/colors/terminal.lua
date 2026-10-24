-- Colorscheme generated from the host terminal's palette (Ghostty, Rex, ...).
-- See lua/config/terminal_palette.lua.
local palette = require("config.terminal_palette")
if not palette.apply() then
  vim.notify("colorscheme terminal: terminal did not report its colors", vim.log.levels.WARN)
  vim.cmd.colorscheme(palette.fallback)
  return
end
vim.g.colors_name = "terminal"
