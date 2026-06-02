return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "everforest",
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

          for _, group in ipairs(groups) do
            vim.api.nvim_set_hl(0, group, { bg = "none" })
          end
        end,
      })
    end,
  },
}
