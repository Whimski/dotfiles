return {
  { "RRethy/nvim-base16", lazy = false },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  { "HiPhish/rainbow-delimiters.nvim" },
  { "godlygeek/tabular" },
  { "NvChad/nvim-colorizer.lua" },
  { "vim-airline/vim-airline" },
  { "vim-airline/vim-airline-themes" },
  {
    "tpope/vim-commentary",
    event = "VeryLazy", -- load on demand
  },
  {
    "mason-org/mason.nvim",
    opts = {}
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup {
        ensure_installed = { "lua", "python", "javascript", "typescript", "c", "cpp", "rust" }, -- adjust
        highlight = { enable = true, additional_vim_regex_highlighting = false },
      }
    end,
  },
  {
    "hiphish/rainbow-delimiters.nvim",
    config = function()
      local rainbow_delimiters = require "rainbow-delimiters"
      vim.g.rainbow_delimiters = {
        highlight = {
          "RainbowRed",
          "RainbowYellow",
          "RainbowBlue",
          "RainbowOrange",
          "RainbowGreen",
          "RainbowViolet",
          "RainbowCyan",
        },
      }
    end
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
    config = function()
      local highlight = {
        "RainbowRed",
        "RainbowYellow",
        "RainbowBlue",
        "RainbowOrange",
        "RainbowGreen",
        "RainbowViolet",
        "RainbowCyan",
      }

      local hooks = require("ibl.hooks")

      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, "RainbowRed",    { fg = "#E06C75" })
        vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
        vim.api.nvim_set_hl(0, "RainbowBlue",   { fg = "#61AFEF" })
        vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
        vim.api.nvim_set_hl(0, "RainbowGreen",  { fg = "#98C379" })
        vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
        vim.api.nvim_set_hl(0, "RainbowCyan",   { fg = "#56B6C2" })
      end)

      hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)

      require("ibl").setup({
        indent = {
          char = "│", -- alternatives: "▏", "┊"
        },
        scope = {
          enabled = true,
          highlight = highlight,
          show_start = false,
          show_end = false,
        },
      })
    end,
  },
  {
    "olrtg/nvim-emmet",
    config = function()
      vim.keymap.set({ "n", "v" }, '<leader>xe', require('nvim-emmet').wrap_with_abbreviation)
    end,
  },
}

