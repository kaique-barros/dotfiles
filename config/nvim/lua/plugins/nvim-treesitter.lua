return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			-- O pcall evita que o Neovim trave se o plugin ainda estiver baixando
			local ok, ts = pcall(require, "nvim-treesitter.configs")
			if not ok then return end
			ts.setup({
				ensure_installed = { "qmljs", "lua", "python", "javascript", "cpp", "bash" },
				highlight = { enable = true },
			})
		end,
	}
}
