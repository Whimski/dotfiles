return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "hrsh7th/cmp-nvim-lsp",
  },
  config = function()
    -- Safe requires
    local ok_lsp, lspconfig = pcall(require, "lspconfig")
    if not ok_lsp then return end

    local ok_mason, mason = pcall(require, "mason")
    local ok_mason_lsp, mason_lspconfig = pcall(require, "mason-lspconfig")
    if not ok_mason or not ok_mason_lsp then return end

    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- Setup Mason
    mason.setup()
    mason_lspconfig.setup({
      ensure_installed = { "pyright", "lua_ls", "clangd", "bashls", "emmet_language_server" },
    })

    -- Use the new recommended setup (avoids deprecated framework)
    if mason_lspconfig.setup_handlers then
      mason_lspconfig.setup_handlers({
        -- default handler for all installed servers
        function(server_name)
          lspconfig[server_name].setup({
            capabilities = capabilities,
            on_attach = function(client, bufnr)
            end,
          })
        end,
      })
    end
  end,
}

