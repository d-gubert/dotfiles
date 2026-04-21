local ok, sessions = pcall(require, "sessions")

if not ok then
	return
end

sessions.setup({
	session_filepath = vim.fn.stdpath("data") .. "/sessions",
	absolute = true,
})

vim.keymap.set(
	"n",
	"<leader>ms",
	"<cmd>SessionsSave<CR>",
	{ desc = "Save session (start up autosave)", noremap = true, silent = true }
)
vim.keymap.set(
	"n",
	"<leader>ml",
	"<cmd>SessionsLoad<CR>",
	{ desc = "Load session (start up autosave)", noremap = true, silent = true }
)
vim.keymap.set("n", "<leader>ma", function()
	sessions.start_autosave()
end, { desc = "Start up session autosave", noremap = true, silent = true })
