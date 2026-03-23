local set = vim.opt

set.number = true
set.tabstop = 4
set.shiftwidth = 4
set.foldmethod = "indent"
set.foldlevel = 99

-- Mostra o erro em uma janela flutuante automaticamente
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, { focusable = false })
  end,
})
