---@diagnostic disable: missing-fields

-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.del({ "n", "x" }, "<leader>gY")
vim.keymap.set({ "n", "x" }, "<leader>gy", function()
    Snacks.gitbrowse({
        open = function(url)
            vim.fn.setreg("+", url)
        end,
        notify = false,
    })
end, { desc = "Git Browse (copy)" })

-- Easy copy to clipboard and past from clipboard
vim.keymap.set({ "n", "v" }, "<A-y>", '"+y', { desc = "Copy to clipboard" })
vim.keymap.set({ "n", "v" }, "<A-p>", '"+p', { desc = "Paste from clipboard" })

-- Better navigation in insert mode. These keymaps mimic shortcuts in the terminal
vim.keymap.set("i", "<C-b>", "<Left>", { desc = "Move one character left" })
vim.keymap.set("i", "<C-f>", "<Right>", { desc = "Move one character right" })
vim.keymap.set("i", "<C-j>", "<Down>", { desc = "Move one line down" })
vim.keymap.set("i", "<C-k>", "<Up>", { desc = "Move one line up" })
vim.keymap.set("i", "<C-e>", "<End>", { desc = "Move to end of line" })
vim.keymap.set("i", "<C-a>", "<Home>", { desc = "Move to beginning of line" })
