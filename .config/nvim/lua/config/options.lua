-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- LazyVim auto format
vim.g.autoformat = false
-- vim.g.lazyvim_eslint_auto_format = true

-- Snacks animations
-- Set to `false` to globally disable all snacks animations
vim.g.snacks_animate = false

local opt = vim.opt

opt.smoothscroll = false
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = false

-- Show invisible characters
opt.list = true
opt.listchars:append("space:⋅")
opt.listchars:append("eol:↴")
opt.listchars:append("tab:▸ ")

opt.clipboard = ""

opt.scrolloff = 8
