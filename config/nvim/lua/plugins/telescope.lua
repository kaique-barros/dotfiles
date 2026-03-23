return {
	{
		'nvim-telescope/telescope.nvim',
		branch = '0.1.x',
		dependencies = { 'nvim-lua/plenary.nvim' },
		keys = {
			{ '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Find files' },
			{ '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = 'Live grep' },
			{ '<leader>fb', '<cmd>Telescope buffers<cr>', desc = 'Buffers' },
			{ '<leader>fh', '<cmd>Telescope help_tags<cr>', desc = 'Help tags' },
		},
		config = function()
			require('telescope').setup({
				defaults = {
					layout_config = { preview_width = 0.6 },
					file_ignore_patterns = { 'node_modules', '.git/' },
				},
			})
		end,
	},
}
