--
-- Tip: only use double leader (e.g. <leader><leader>) for maps you won't be using often
--

vim.g.mapleader = " "

-- Open Netrw - currently being overwritten by Oil.nvim
vim.keymap.set("n", "<leader>e", vim.cmd.Ex, { desc = "Open Netrw" })

-- Tabs
vim.keymap.set("n", "<leader>t]", function()
	vim.cmd("tabnext")
end, { desc = "Cycle Tab" })

vim.keymap.set("n", "<leader>tn", function()
	vim.cmd("tabnew")
end, { desc = "New tab" })

vim.keymap.set("n", "<leader>tc", function()
	vim.cmd("tabclose")
end, { desc = "Close current tab" })

-- Easy window handling (pressing ctrl is too much wrist displacement) - been using this even with capslock as CTRL
vim.keymap.set("n", "<leader>w", "<C-w>", { desc = "Window handling" })
vim.keymap.set("n", "<A-w>", "<C-w>", { desc = "Window handling" })

-- Pressing ESC is too much wrist displacement - not a problem when using capslock as CTRL - <C-[>
-- vim.keymap.set('i', 'jk', '<ESC>', { desc = 'Easy escape (pressing ESC is too much wrist displacement)' })

-- Better navigation in insert mode. These keymaps mimic shortcuts in the terminal
vim.keymap.set("i", "<C-b>", "<Left>", { desc = "Move one character left" })
vim.keymap.set("i", "<C-f>", "<Right>", { desc = "Move one character right" })
vim.keymap.set("i", "<C-j>", "<Down>", { desc = "Move one line down" })
vim.keymap.set("i", "<C-k>", "<Up>", { desc = "Move one line up" })
vim.keymap.set("i", "<C-e>", "<End>", { desc = "Move to end of line" })
vim.keymap.set("i", "<C-a>", "<Home>", { desc = "Move to beginning of line" })

-- Quick saving, faster than typing the commands
vim.keymap.set("n", "<leader>s", vim.cmd.write, { remap = false, desc = "Save" })

vim.keymap.set("n", "<leader>qs", function()
	vim.cmd([[wq]])
end, { remap = false, desc = "Save and quit" })

vim.keymap.set("n", "<leader>qf", function()
	vim.cmd([[w!]])
end, { remap = false, desc = "Force quit" })

-- Toggle relative number if sharing screen so others don't get confusion
vim.keymap.set("n", "<leader><leader>n", function()
	vim.opt.relativenumber = not vim.opt.relativenumber:get()
end, { desc = "Toggle relative line number" })

-- Easy copy/paste to clipboard
vim.keymap.set({ "n", "v" }, "<A-y>", '"+y', { desc = "Copy to clipboard" })
vim.keymap.set({ "n", "v" }, "<A-p>", '"+p', { desc = "Paste from clipboard" })

-- Move highlighted lines on visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move highlighted lines down on visual mode" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move highlighted lines up on visual mode" })

-- Move to search result and centralize viewport
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Easy clear search highlights
vim.keymap.set("n", "<ESC>", ":noh<CR>", { desc = "Clear search highlights", silent = true })

-- Page scroll and centralize
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Page scroll and centralize" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Page scroll and centralize" })
vim.keymap.set("n", "<A-d>", "<C-d>zz", { desc = "Page scroll and centralize" })
vim.keymap.set("n", "<A-u>", "<C-u>zz", { desc = "Page scroll and centralize" })

-- Alt is closer than CTRL (less wrist displacement)
-- Obsolete since I've remapped my capslock to CTRL
-- vim.keymap.set("", "<A-p>", "<C-p>")
-- vim.keymap.set("", "<A-n>", "<C-n>")
-- vim.keymap.set("", "<A-m>", "<C-m>")
-- vim.keymap.set("i", "<A-c>", "<ESC>")
-- vim.keymap.set("i", "<A-w>", "<C-w>")
-- vim.keymap.set("i", "<A-u>", "<C-u>")

-- Better <Del>
vim.keymap.set("i", "<C-l>", "<Del>", { desc = "Better <Del>" })

-- Join lines without moving cursor (as the default would do)
vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines without moving cursor" })

-- Paste over (replace) visual highlight without overwriting default register
vim.keymap.set(
	"x",
	"<leader>p",
	[["_dP]],
	{ desc = "Paste over (replace) visual highlight without overwriting default register" }
)

-- Easy close all
vim.keymap.set("n", "<leader>qa", function()
	vim.cmd("qa")
end, { desc = "Close all" })

-- Buffer navigation
vim.keymap.set("n", "<leader>bp", function()
	vim.cmd("bp")
end, { desc = "Previous buffer" })

vim.keymap.set("n", "<leader>bn", function()
	vim.cmd("bn")
end, { desc = "Next buffer" })

-- Close window types
vim.keymap.set("n", "<leader>cch", function()
	vim.cmd("helpclose")
end, { desc = "Close help window" })

vim.keymap.set("n", "<leader>ccl", function()
	vim.cmd("lclose")
end, { desc = "Close location window" })

vim.keymap.set("n", "<leader>ccq", function()
	vim.cmd("cclose")
end, { desc = "Close quickfix window" })

vim.keymap.set("n", "<leader>ccp", function()
	vim.cmd("pclose")
end, { desc = "Close preview window" })

-- Terminal emulator
vim.keymap.set("t", "<ESC>", "<C-\\><C-n>", { desc = "Terminal: Escape" })
-- vim.keymap.set("t", "<C-[>", "<C-\\><C-n>", { desc = "Terminal: Escape" })

-- Custom Line Highlights
local customHighlight = require("d-gubert.custom-highlight")

vim.keymap.set("n", "<leader>lh", function()
	customHighlight.highlight()
end, { desc = "Line highlight" })
