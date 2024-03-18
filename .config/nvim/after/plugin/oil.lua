local ok, oil = pcall(require, "oil")

if not ok then
	return
end

oil.setup({
	default_file_explorer = false,
	view_options = {
		show_hidden = true,
	},
	float = {
		padding = 10,
	},
	keymaps = {
		['<C-v>'] = 'actions.select_vsplit',
		['<C-s>'] = nil,
	},
})

vim.keymap.set('n', '<leader>e', '<cmd>Oil --float<cr>', { desc = 'Explore File system (Oil.nvim)', noremap = true, silent = true })
