return {
  "okuuva/auto-save.nvim",
  cmd = "ASToggle", -- opcional: permite ligar/desligar
  event = { "InsertLeave", "TextChanged" }, -- salva ao sair do modo de inserção ou mudar texto
  opts = {
    enabled = true,
    trigger_events = {"InsertLeave", "TextChanged"},
    -- cancela o autosave se o arquivo for de um tipo específico (ex: gitcommit)
    condition = function(buf)
      local fn = vim.fn
      local utils = require("auto-save.utils.data")
      if fn.getbufvar(buf, "&modifiable") == 1 and
         utils.not_in(fn.getbufvar(buf, "&filetype"), {"gitcommit", "netrw"}) then
        return true
      end
      return false
    end,
  },
}
