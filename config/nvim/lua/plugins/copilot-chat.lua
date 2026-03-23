return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    dependencies = {
      { "github/copilot.vim" }, -- Depende do que você já instalou
      { "nvim-lua/plenary.nvim" }, -- Para operações assíncronas
    },
    opts = {
      debug = false, -- Defina como true para ver logs
	  model = 'claude-opus-4.6', -- Modelo a ser usado
    },
    keys = {
      { "<leader>cc", "<cmd>CopilotChatToggle<cr>", desc = "CopilotChat - Alternar" },
      { "<leader>ce", "<cmd>CopilotChatExplain<cr>", desc = "CopilotChat - Explicar código" },
    },
  },
}
