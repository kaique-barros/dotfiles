return {
	{
		"nvim-tree/nvim-tree.lua",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		keys = { { "<leader>e", "<cmd>NvimTreeToggle<CR>" } },
		opts = { sync_root_with_cwd = true, renderer = { highlight_git = true } }
	}
}
