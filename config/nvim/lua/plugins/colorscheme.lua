return {
  {
    "LazyVim/LazyVim",
    opts = {
      -- Follow the terminal palette (Ghostty, Rex, ...); falls back to everforest.
      colorscheme = function()
        require("config.terminal_palette").load()
      end,
    },
    init = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          local groups = {
            "Normal",
            "NormalNC",
            "NormalFloat",
            "FloatBorder",
            "SignColumn",
            "EndOfBuffer",
            "LineNr",
            "FoldColumn",
            "StatusLine",
            "StatusLineNC",
            "TabLineFill",
          }

          -- Clear only the background (keep fg/bold/etc.) so the terminal's
          -- background, including its opacity/blur, shows through.
          for _, group in ipairs(groups) do
            local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
            hl.bg, hl.ctermbg = nil, nil
            vim.api.nvim_set_hl(0, group, hl)
          end
        end,
      })
    end,
  },
}
