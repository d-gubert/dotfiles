local ok, _ = pcall(require, "leap")

if not ok then
	return
end

-- leap.create_default_mappings()
vim.keymap.set("n", "s", "<Plug>(leap-forward)", { desc = "Leap forward", noremap = true })
vim.keymap.set("n", "S", "<Plug>(leap-backward)", { desc = "Leap backward", noremap = true })
vim.keymap.set("n", "gx", "<Plug>(leap-from-window)", { desc = "Leap from window" })

-- Until https://github.com/neovim/neovim/issues/20793 is fixed, we need to
-- Hide the (real) cursor when leaping, and restore it afterwards.
vim.api.nvim_create_autocmd("User", {
	pattern = "LeapEnter",
	callback = function()
		vim.cmd.hi("Cursor", "blend=100")
		vim.opt.guicursor:append({ "a:Cursor/lCursor" })
	end,
})

vim.api.nvim_create_autocmd("User", {
	pattern = "LeapLeave",
	callback = function()
		vim.cmd.hi("Cursor", "blend=0")
		vim.opt.guicursor:remove({ "a:Cursor/lCursor" })
	end,
})
