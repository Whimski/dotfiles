return {
  "lukas-reineke/indent-blankline.nvim",
  event = { "BufReadPost", "BufNewFile", "TabEnter" },
  config = function()
    local ibl_ok, ibl = pcall(require, "ibl")
    if not ibl_ok then return end

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
