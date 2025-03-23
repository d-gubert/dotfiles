-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- LazyVim auto format
vim.g.autoformat = false

-- Snacks animations
-- Set to `false` to globally disable all snacks animations
vim.g.snacks_animate = false

local opt = vim.opt

opt.tabstop = 4 -- Number of spaces tabs count for
opt.smoothscroll = false

-- Show invisible characters
opt.list = true
opt.listchars:append("space:⋅")
opt.listchars:append("eol:↴")
opt.listchars:append("tab:▸ ")

opt.clipboard = ""

opt.scrolloff = 8
