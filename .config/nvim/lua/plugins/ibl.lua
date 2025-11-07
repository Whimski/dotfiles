return {
  "lukas-reineke/indent-blankline.nvim",
  event = { "BufReadPost", "BufNewFile", "TabEnter" },
  config = function()
    local ibl_ok, ibl = pcall(require, "ibl")
    if not ibl_ok then return end

    local hl = vim.api.nvim_set_hl
    hl(0, "RainbowCyan", { fg="#56B6C2" })

    ibl.setup({
      indent = {
        char = "|",
        highlight = { "LineNr" },
      },
      scope = {
        enabled = true,
        highlight = { "RainbowCyan" },
      },
    })

    -- Refresh on tab switch or buffer enter
    vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter", "TabEnter" }, {
      callback = function()
        vim.schedule(function() ibl.update() end)
      end,
    })
  end,
}
