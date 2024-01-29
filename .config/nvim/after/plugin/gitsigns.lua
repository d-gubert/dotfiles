local ok, gitsigns = pcall(require, "gitsigns")

if not ok then
	return
end

gitsigns.setup({
	on_attach = function(bufnr)
		local gs = package.loaded.gitsigns

		vim.keymap.set("n", "<leader>gha", gs.stage_hunk, { desc = "Stage Git hunk", buffer = bufnr })
		vim.keymap.set("n", "<leader>ghu", gs.undo_stage_hunk, { desc = "Undo stage Git hunk", buffer = bufnr })
		vim.keymap.set("n", "<leader>ghr", gs.reset_hunk, { desc = "Reset Git hunk", buffer = bufnr })
		vim.keymap.set("n", "<leader>ghp", gs.preview_hunk, { desc = "Preview Git hunk", buffer = bufnr })
		vim.keymap.set("n", "<leader>ghd", gs.diffthis, { desc = "Diff this (?)", buffer = bufnr })

		vim.keymap.set({"o", "x"}, "ih", gs.select_hunk, { desc = "Select Git hunk", buffer = bufnr })
	end,
})


