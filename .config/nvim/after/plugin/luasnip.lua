require("luasnip.loaders.from_vscode").load()

local luasnip = require("luasnip")

vim.keymap.set("s", "<C-n>", function() luasnip.jump(1) end, { desc = "Jump to next snippet" })
vim.keymap.set("s", "<C-p>", function() luasnip.jump(-1) end, { desc = "Jump to previous snippet" })
