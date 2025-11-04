local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Leader key
vim.g.mapleader = ","  -- space as leader

-- General keymaps
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
map("n", "<leader>h", "<cmd>nohlsearch<CR>", { desc = "Clear highlights" })

-- Mason
map("n", "<leader>m", "<cmd>Mason<CR>", { desc = "Open Mason" })

-- LSP
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "K", vim.lsp.buf.hover, { desc = "Show hover info" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
