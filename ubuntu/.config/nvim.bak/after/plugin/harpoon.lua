local ok, harpoon = pcall(require, "harpoon")

if not ok then
	return
end

harpoon.setup()

vim.keymap.set("n", "<leader>ha", function() harpoon:list():append() end, { desc = "Harpoon append" })
vim.keymap.set("n", "<leader>he", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon quick menu" })

vim.keymap.set("n", "<leader>1", function() harpoon:list():select(1) end, { desc = "Harpoon select file 1" })
vim.keymap.set("n", "<leader>2", function() harpoon:list():select(2) end, { desc = "Harpoon select file 2" })
vim.keymap.set("n", "<leader>3", function() harpoon:list():select(3) end, { desc = "Harpoon select file 3" })
vim.keymap.set("n", "<leader>4", function() harpoon:list():select(4) end, { desc = "Harpoon select file 4" })
vim.keymap.set("n", "<leader>5", function() harpoon:list():select(5) end, { desc = "Harpoon select file 5" })

-- Toggle previous & next buffers stored within Harpoon list
vim.keymap.set("n", "<leader>[", function() harpoon:list():prev() end, { desc = "Harpoon select previous file" })
vim.keymap.set("n", "<leader>]", function() harpoon:list():next() end, { desc = "Harpoon select next file" })
