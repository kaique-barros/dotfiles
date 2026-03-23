return {
  "github/copilot.vim",
  config = function()
    vim.g.copilot_no_tab_map = true
    vim.api.nvim_set_keymap("i", "<C-U>", 'copilot#Accept("<CR>")', {
      silent = true,
      expr = true,
      replace_keycodes = false,
    })
    
    -- Opcional: Desabilitar o Copilot para tipos de arquivos específicos
    vim.g.copilot_filetypes = {
      ["markdown"] = false,
      ["help"] = false,
    }
  end,
}
