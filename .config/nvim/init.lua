-- ===========
-- BASIC SETTINGS
-- ===========
vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
    pattern = "*",
    callback = function()
      vim.opt.shiftwidth = 2
      vim.opt.tabstop = 2
      vim.opt.softtabstop = 2
      vim.opt.expandtab = true
      vim.opt.incsearch = true
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.showmatch = true
      vim.opt.hlsearch = true
      vim.opt.backupcopy = "yes"
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.cmd('filetype plugin indent on')
      vim.cmd("syntax off")
      vim.o.termguicolors = true
    end,
})

-- ===========
-- PLUGIN CONFIG
-- ===========
vim.g.mapleader = ","
vim.g.maplocalleader = ","

vim.g.python_recommended_style = 0

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
require('lualine').setup{
  options = { theme = 'ayu_mirage' }
}
require('nvim-treesitter.configs').setup {
  ensure_installed = {
    "c", "cpp", "lua", "python", "javascript", "html", "css"
  },
  sync_install = false,
  auto_install = true,

  highlight = {
    enable = true,
    -- disable = { "csv" },
    additional_vim_regex_highlighting = false,
  },

  indent = { enable = true },
}

require("colorizer").setup({
  filetypes = { "css", "scss", "html", "javascript", "lua", "python" },
  user_default_options = {
    RGB      = true,
    RRGGBB   = true,
    names    = true,
    RRGGBBAA = true,
    rgb_fn   = true,
    hsl_fn   = true,
    css      = true,
    css_fn   = true,
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

-- Telescope
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })

vim.api.nvim_create_autocmd("TabEnter", {
  callback = function()
    local ok, ibl = pcall(require, "ibl")
    if ok then
      ibl.update()
    end
  end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    local hl = vim.api.nvim_set_hl
    hl(0, "RainbowRed", { fg="#E06C75" })
    hl(0, "RainbowYellow", { fg="#E5C07B" })
    hl(0, "RainbowBlue", { fg="#61AFEF" })
    hl(0, "RainbowOrange", { fg="#D19A66" })
    hl(0, "RainbowGreen", { fg="#98C379" })
    hl(0, "RainbowViolet", { fg="#C678DD" })
    hl(0, "RainbowCyan", { fg="#56B6C2" })
  end,
})

vim.keymap.set('n', '<S-j>', '<C-f>', { noremap = true, silent = true })
vim.keymap.del('n', '<S-k>')
vim.keymap.set('n', '<S-k>', '<C-b>', { noremap = true, silent = true })
