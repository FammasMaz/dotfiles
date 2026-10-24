-- Build the Neovim colorscheme from the terminal's own colors.
--
-- The 16 ANSI colors plus the default foreground/background are read from the
-- host terminal with OSC 4/10/11 queries (Ghostty, Rex, and most modern
-- terminals answer them), turned into a base16 palette, and applied with
-- mini.base16. When the terminal switches light/dark, Neovim updates
-- 'background' on its own (DEC mode 2031 + OSC 11); we hook that to re-query
-- and re-apply. Terminals that don't answer fall back to M.fallback.

local M = {}

M.fallback = "everforest"

---@type table<string|integer, string>?
M.colors = nil

local function parse_rgb(spec)
  local r, g, b = spec:match("^rgba?:(%x+)/(%x+)/(%x+)")
  if not r then
    return nil
  end
  local function scale(h)
    return math.floor(tonumber(h, 16) * 255 / (16 ^ #h - 1) + 0.5)
  end
  return string.format("#%02x%02x%02x", scale(r), scale(g), scale(b))
end

local function complete(c)
  if not (c.bg and c.fg) then
    return false
  end
  for i = 0, 15 do
    if not c[i] then
      return false
    end
  end
  return true
end

--- Ask the terminal for its colors. Calls `cb(colors)` when the terminal has
--- answered (colors is nil if it did not report all of them).
---
--- A DSR (CSI 5 n) is sent last; its reply means the terminal has answered
--- everything before it. At startup nothing else is querying the terminal, so
--- the first DSR reply is ours. Later, Neovim's own theme-change handling may
--- send a DSR of its own, so `async` waits for a complete palette instead.
---@param cb fun(colors: table|nil)
---@param async? boolean
---@return fun(): boolean finished  -- poll function for vim.wait
local function query(cb, async)
  local colors, finished = {}, false
  local function finish()
    if not finished then
      finished = true
      cb(complete(colors) and colors or nil)
    end
  end

  local id = vim.api.nvim_create_autocmd("TermResponse", {
    desc = "Collect terminal palette replies",
    callback = function(ev)
      local seq = type(ev.data) == "table" and ev.data.sequence or ev.data
      if type(seq) ~= "string" then
        return
      end
      local idx, spec = seq:match("^\027%]4;(%d+);(rgba?:[%x/]+)")
      if idx then
        colors[tonumber(idx)] = parse_rgb(spec)
        return
      end
      spec = seq:match("^\027%]10;(rgba?:[%x/]+)")
      if spec then
        colors.fg = parse_rgb(spec)
        return
      end
      spec = seq:match("^\027%]11;(rgba?:[%x/]+)")
      if spec then
        colors.bg = parse_rgb(spec)
        return
      end
      if seq:match("^\027%[0n$") and (complete(colors) or not async) then
        finish()
        return true -- delete this autocmd
      end
    end,
  })

  local req = {}
  for i = 0, 15 do
    req[#req + 1] = ("\027]4;%d;?\027\\"):format(i)
  end
  req[#req + 1] = "\027]10;?\027\\\027]11;?\027\\\027[5n"
  vim.api.nvim_ui_send(table.concat(req))

  -- Give up if the terminal never answers the DSR.
  vim.defer_fn(function()
    if not finished then
      pcall(vim.api.nvim_del_autocmd, id)
      finish()
    end
  end, 1000)

  return function()
    return finished
  end
end

-- Color math -----------------------------------------------------------------

local function to_rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

local function mix(a, b, t)
  local ar, ag, ab = to_rgb(a)
  local br, bg, bb = to_rgb(b)
  local function m(x, y)
    return math.floor(x + (y - x) * t + 0.5)
  end
  return string.format("#%02x%02x%02x", m(ar, br), m(ag, bg), m(ab, bb))
end

local function luminance(hex)
  local function lin(c)
    c = c / 255
    return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
  end
  local r, g, b = to_rgb(hex)
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
end

-- Same rule Neovim uses to set 'background' from the terminal's OSC 11 reply.
-- Using a different rule here would make the two fight over 'background'.
local function is_dark(hex)
  local r, g, b = to_rgb(hex)
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255 < 0.5
end

local function contrast(a, b)
  local la, lb = luminance(a), luminance(b)
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- Push `color` away from `bg` until it reaches `min` contrast.
local function readable(color, bg, min)
  local target = is_dark(bg) and "#ffffff" or "#000000"
  local t, out = 0, color
  while contrast(out, bg) < min and t < 1 do
    t = t + 0.05
    out = mix(color, target, t)
  end
  return out
end

--- Map terminal colors to a base16 palette.
function M.base16(c)
  local bg, fg = c.bg, c.fg
  local extreme = is_dark(bg) and "#ffffff" or "#000000"
  local function accent(x)
    return readable(x, bg, 3.0)
  end
  return {
    base00 = bg,
    base01 = mix(bg, fg, 0.08),
    base02 = mix(bg, fg, 0.17),
    base03 = readable(c[8], bg, 2.6),
    base04 = mix(bg, fg, 0.65),
    base05 = fg,
    base06 = mix(fg, extreme, 0.25),
    base07 = mix(fg, extreme, 0.5),
    base08 = accent(c[1]),
    base09 = accent(mix(c[1], c[3], 0.5)),
    base0A = accent(c[3]),
    base0B = accent(c[2]),
    base0C = accent(c[6]),
    base0D = accent(c[4]),
    base0E = accent(c[5]),
    base0F = accent(mix(c[1], bg, 0.3)),
  }
end

local function has_tui()
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.stdout_tty then
      return true
    end
  end
  return false
end

--- Query the terminal if we haven't yet. Blocks for at most 100 ms (a local
--- terminal answers in well under 1 ms; this is the same budget Neovim uses
--- for its own 'background' detection).
function M.ensure()
  if not M.colors and has_tui() then
    local done = query(function(colors)
      M.colors = colors
    end)
    vim.wait(100, done, 1)
  end
  return M.colors ~= nil
end

--- Apply the palette (called by colors/terminal.lua).
function M.apply()
  if not M.ensure() then
    return false
  end
  -- Don't set 'background' here: Neovim sets it from the same OSC 11 reply
  -- (with the same rule as is_dark), and setting it from a script makes
  -- Neovim stop tracking the terminal's light/dark changes.
  require("mini.base16").setup({ palette = M.base16(M.colors) })
  return true
end

local augroup = vim.api.nvim_create_augroup("terminal_palette", { clear = true })

--- Entry point for LazyVim's `colorscheme` option.
function M.load()
  if M.ensure() then
    vim.cmd.colorscheme("terminal")
  else
    vim.cmd.colorscheme(M.fallback)
  end

  -- Neovim 0.12's TUI subscribes to theme-change notifications (DEC mode
  -- 2031) and re-detects 'background'. When that flips, re-read the palette.
  vim.api.nvim_create_autocmd("OptionSet", {
    group = augroup,
    pattern = "background",
    callback = function()
      -- Our own query also gets an OSC 11 reply, which makes Neovim set
      -- 'background' again (to the same value); ignore that.
      if vim.v.option_old == vim.v.option_new or M._querying then
        return
      end
      if vim.g.colors_name ~= "terminal" then
        return
      end
      M.refresh()
    end,
  })
end

--- Re-query the terminal and re-apply if its colors changed.
---@param force? boolean re-apply even if the colors are unchanged
function M.refresh(force)
  if M._querying then
    return
  end
  M._querying = true
  query(function(colors)
    M._querying = false
    if not colors then
      if force then
        vim.notify("Terminal did not report its colors", vim.log.levels.WARN)
      end
      return
    end
    if force or not vim.deep_equal(colors, M.colors) then
      M.colors = colors
      -- Outside the TermResponse callback, so ColorScheme autocmds (transparency,
      -- lualine, ...) run as they do for a normal :colorscheme.
      vim.schedule(function()
        vim.cmd.colorscheme("terminal")
      end)
    end
  end, true)
end

vim.api.nvim_create_user_command("TerminalPaletteSync", function()
  M.refresh(true)
end, { desc = "Re-read the terminal palette and re-apply the colorscheme" })

return M
