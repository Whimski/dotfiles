-- ===========
-- BASIC SETTINGS
-- ===========
local opt = vim.opt

opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.expandtab = true
-- opt.nobackup = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.showmatch = true
opt.hlsearch = true
opt.backupcopy = "yes"
opt.number = true
opt.relativenumber = true
vim.cmd("syntax enable")

-- ===========
-- PLUGIN CONFIG
-- ===========
vim.g.mapleader = ","
vim.g.maplocalleader = ","
vim.g.python_recommended_style = 0
-- Enable Powerline-style fonts
vim.g.airline_powerline_fonts = 1

-- Choose a theme
vim.g.airline_theme = 'wombat'

-- Show tabline (buffers on top)
vim.g["airline#extensions#tabline#enabled"] = 0
vim.g["airline#extensions#tabline#formatter"] = 'default'

-- Optional: enable ALE/LSP indicators
vim.g["airline#extensions#ale#enabled"] = 1

-- ===========
-- PLUGIN MANAGEMENT (lazy.nvim)
-- ===========
-- Auto-install lazy.nvim if missing
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")
require("keymaps")
require("colorizer").setup({
  filetypes = { "css", "scss", "html", "javascript", "lua", "python" },
  user_default_options = {
    RGB      = true, -- #RGB hex codes
    RRGGBB   = true, -- #RRGGBB hex codes
    names    = true, -- "Blue" or "red"
    RRGGBBAA = true, -- #RRGGBBAA hex codes
    rgb_fn   = true, -- rgb() and rgba()
    hsl_fn   = true, -- hsl() and hsla()
    css      = true, -- Enable all CSS features
    css_fn   = true, -- Enable all CSS *functions*
  },
})

-- ===========
-- AUTOCOMMANDS
-- ===========
vim.api.nvim_create_autocmd("BufEnter", {
  -- pattern = "*.py",
  callback = function()
    vim.cmd("colorscheme catppuccin-mocha")
    vim.cmd("highlight Normal guibg=NONE ctermbg=NONE")
    vim.cmd("highlight Pmenu ctermfg=15 ctermbg=0")
    vim.cmd("highlight Search ctermfg=15 ctermbg=0")
    vim.cmd("highlight LineNr ctermbg=NONE")
  end,
})

