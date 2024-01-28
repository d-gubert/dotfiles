local ok, luasnip = pcall(require, "luasnip")

if not ok then
	return
end

require("luasnip.loaders.from_vscode").lazy_load()

vim.keymap.set("s", "<C-n>", function() luasnip.jump(1) end, { desc = "Jump to next snippet" })
vim.keymap.set("s", "<C-p>", function() luasnip.jump(-1) end, { desc = "Jump to previous snippet" })
