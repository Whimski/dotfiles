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
	"lukas-reineke/indent-blankline.nvim",
	main = "ibl",
	opts = function(_, opts)
		-- Other blankline configuration here
		return require("indent-rainbowline").make_opts(opts)
	end,
	dependencies = {
		"TheGLander/indent-rainbowline.nvim",
	},
  }
}

