return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
		},
		config = function()
			-- Inicializa o Mason ANTES do lspconfig
			require("mason").setup()
			local lspconfig = require("lspconfig")
			local mason_lspconfig = require("mason-lspconfig")

			mason_lspconfig.setup({
				ensure_installed = { "pyright", "ts_ls", "clangd", "lua_ls", "qmlls" }
			})

			local on_attach = function(_, bufnr)
				local opts = { buffer = bufnr }
				vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
				vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename, opts)
			end

			-- Handler automático (Apenas se o plugin estiver pronto)
			if mason_lspconfig.setup_handlers then
				mason_lspconfig.setup_handlers({
					function(server_name)
						lspconfig[server_name].setup({ on_attach = on_attach })
					end,
					["lua_ls"] = function()
						lspconfig.lua_ls.setup({
							on_attach = on_attach,
							settings = { Lua = { diagnostics = { globals = { "vim" } } } }
						})
					end,
				})
			end
		end,
	}
}
