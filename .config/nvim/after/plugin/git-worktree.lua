local ok, worktree = pcall(require, "git-worktree")

if not ok then
	return
end

worktree.setup()


local telescope = require("telescope")

telescope.load_extension("git_worktree")

vim.keymap.set('n', '<leader>gw', telescope.extensions.git_worktree.git_worktrees)
