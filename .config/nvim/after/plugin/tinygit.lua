local ok, tinygit = pcall(require, "tinygit")

if not ok then
	return
end

tinygit.setup({
	commitMsg = {
		-- Why 50/72 is recommended: https://stackoverflow.com/q/2290016/22114136
		mediumLen = 50,
		maxLen = 72,

		-- When conforming the commit message popup with an empty message, fill in
		-- this message. Set to `false` to disallow empty commit messages.
		emptyFillIn = false, ---@type string|false

		-- Shows diffstats of the changes that are going to be committed.
		-- (requires nvim-notify)
		commitPreview = true,

		conventionalCommits = {
			enforce = false, -- disallow commit messages without a keyword
			-- stylua: ignore
			keywords = {
				"fix", "feat", "chore", "docs", "refactor", "build", "test",
				"perf", "style", "revert", "ci", "break", "improv",
			},
		},

		-- enable vim's builtin spellcheck for the commit message input field.
		-- (configured to ignore capitalization and correctly consider camelCase)
		spellcheck = false,

		-- if commit message references issue/PR, open it in the browser
		openReferencedIssue = false,
	},
})

vim.keymap.set("n", "<leader>gc", tinygit.smartCommit, { desc = "Tinygit smart commit" })
vim.keymap.set("n", "<leader>gh", tinygit.searchFileHistory, { desc = "Tinygit search file history" })
