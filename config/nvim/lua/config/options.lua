local set = vim.opt

set.number = true
set.tabstop = 2
set.shiftwidth = 2
set.softtabstop = 2
set.expandtab = true
set.foldmethod = "indent"
set.foldlevel = 99

-- Mostra o erro em uma janela flutuante automaticamente
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, { focusable = false })
  end,
})
