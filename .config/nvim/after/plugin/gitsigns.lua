local ok, gitsigns = pcall(require, "gitsigns")

if not ok then
	return
end

gitsigns.setup({
	on_attach = function(bufnr)
		local gs = package.loaded.gitsigns

		vim.keymap.set("n", "]h", function()
			if vim.wo.diff then
				return "]h"
			end
			vim.schedule(function()
				gs.next_hunk()
			end)
			return "<Ignore>"
		end, { expr = true, buffer = bufnr })

		vim.keymap.set("n", "[h", function()
			if vim.wo.diff then
				return "[h"
			end
			vim.schedule(function()
				gs.prev_hunk()
			end)
			return "<Ignore>"
		end, { expr = true, buffer = bufnr })

		vim.keymap.set("n", "<leader>ha", gs.stage_hunk, { desc = "Stage Git hunk", buffer = bufnr })
		vim.keymap.set("n", "<leader>hu", gs.undo_stage_hunk, { desc = "Undo stage Git hunk", buffer = bufnr })
		vim.keymap.set("n", "<leader>hr", gs.reset_hunk, { desc = "Reset Git hunk", buffer = bufnr })
		vim.keymap.set("n", "<leader>hp", gs.preview_hunk, { desc = "Preview Git hunk", buffer = bufnr })
		vim.keymap.set("n", "<leader>hd", gs.diffthis, { desc = "Diff this (?)", buffer = bufnr })

		vim.keymap.set({ "o", "x" }, "ih", gs.select_hunk, { desc = "Select Git hunk", buffer = bufnr })
	end,
})
