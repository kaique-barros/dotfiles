vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Ir para a janela da esquerda' })

local builtin = require('telescope.builtin')

vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Buscar Arquivos' })

vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Buscar Texto (Grep)' })

vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Listar Buffers' })

vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Buscar Ajuda' })

vim.keymap.set('n', '<leader>gc', builtin.git_commits, { desc = 'Commits do Git' })

vim.keymap.set('n', '<leader>fi', ":Telescope media_files<CR>", { desc = 'Buscar Imagens/Mídia' })

-- Navegar entre arquivos (Buffers) com Ctrl + Setas
vim.keymap.set('n', '<C-Right>', '<cmd>BufferLineCycleNext<CR>', { desc = 'Próximo Buffer' })
vim.keymap.set('n', '<C-Left>', '<cmd>BufferLineCyclePrev<CR>', { desc = 'Buffer Anterior' })

-- Desmarcar busca com Esc
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set('n', 'gl', vim.diagnostic.open_float, { desc = 'Ver erro detalhado' })
