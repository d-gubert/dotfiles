local ok, tinygit = pcall(require, "tinygit")

if not ok then
  return
end

tinygit.setup({
	commitMsg = {
		emptyFillIn = false,
	}
})

vim.keymap.set('n', '<leader>gc', tinygit.smartCommit, { desc = 'Tinygit smart commit' })
vim.keymap.set('n', '<leader>gh', tinygit.searchFileHistory, { desc = 'Tinygit search file history' })
