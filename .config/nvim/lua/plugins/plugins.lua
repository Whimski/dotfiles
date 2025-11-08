return {
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  { "HiPhish/rainbow-delimiters.nvim" },
  { "godlygeek/tabular" },
  { "NvChad/nvim-colorizer.lua" },
  {
    "mason-org/mason.nvim",
    opts = {}
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
    end,
  },
  {
    "olrtg/nvim-emmet",
    config = function()
      vim.keymap.set({ "n", "v" }, '<leader>xe', require('nvim-emmet').wrap_with_abbreviation)
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' }
  },
  {
    'nvim-telescope/telescope.nvim', tag = '0.1.8',
      dependencies = { 'nvim-lua/plenary.nvim' }
  },
  {
    'numToStr/Comment.nvim',
    opts = {}
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
    },
  },
  { 'nvim-mini/mini.nvim', version = false },
}

