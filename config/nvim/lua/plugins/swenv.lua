return {
  "AckslD/swenv.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require('swenv').setup({
      get_venvs = function()
        local envs = {}
        local conda_path = "/home/kaiqbbrs/miniconda3/envs"
        local p = io.popen('ls -d ' .. conda_path .. '/*/')
        
        if p then
          for dir in p:lines() do
            -- Limpa o caminho para pegar só o nome da pasta
            local name = dir:match(".*/([^/]+)/$")
            table.insert(envs, {
              name = name,
              path = dir,
              source = "conda",
            })
          end
          p:close()
        end
        
        -- Adiciona o ambiente base manualmente para garantir
        table.insert(envs, { name = "base", path = "/home/kaiqbbrs/miniconda3/", source = "conda" })
        
        return envs
      end,
      post_set_venv = function()
        vim.cmd("LspRestart")
      end,
    })
  end,
  keys = {
    { "<leader>cv", function() require('swenv.api').pick_venv() end, desc = "Selecionar Python Env" },
  },
}
