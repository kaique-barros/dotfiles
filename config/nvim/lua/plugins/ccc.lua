return {
  {
    "uga-rosa/ccc.nvim",
    event = "BufReadPre",
    opts = {
      -- Configurações para abrir o seletor visual
      highlighter = {
        auto_enable = true,
        lsp = true,
      },
    },
    config = function(_, opts)
      local ccc = require("ccc")
      ccc.setup(opts)

      -- Atalho opcional para abrir o seletor de cores manualmente (ex: <leader>cp)
      vim.keymap.set("n", "<leader>cp", "<cmd>CccPick<CR>", { desc = "Abrir Color Picker" })
    end,
  },
}
