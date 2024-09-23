-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd([[packadd packer.nvim]])

local ensure_packer = function()
	local fn = vim.fn
	local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
	if fn.empty(fn.glob(install_path)) > 0 then
		fn.system({ "git", "clone", "--depth", "1", "https://github.com/wbthomason/packer.nvim", install_path })
		vim.cmd([[packadd packer.nvim]])
		return true
	end
	return false
end

ensure_packer()

return require("packer").startup(function(use)
	-- Packer can manage itself
	use("wbthomason/packer.nvim")

	-- Let's take care of our time
	use("wakatime/vim-wakatime")

	use({ "iamcco/markdown-preview.nvim", run = "cd app && npm install", setup = function() vim.g.mkdp_filetypes = { "markdown" } end, ft = { "markdown" } })

	use({
		"epwalsh/obsidian.nvim",
		tag = "*", -- recommended, use latest release instead of latest commit
		requires = {
			-- Required.
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
			"nvim-treesitter/nvim-treesitter",
			"hrsh7th/nvim-cmp",
		},
	})

	use({
		"nvim-telescope/telescope.nvim",
		tag = "0.1.5",
		-- or                            , branch = '0.1.x',
		requires = {
			{ "nvim-lua/plenary.nvim" },
			{ "nvim-telescope/telescope-ui-select.nvim" },
			-- REQUIRED! This allows for further refinement of search results
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				run = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
			},
		},
	})

	use({
		"nvim-treesitter/nvim-treesitter",
		run = ":TSUpdate",
		requires = {
			"nvim-treesitter/playground",
			"nvim-treesitter/nvim-treesitter-refactor",
			"nvim-treesitter/nvim-treesitter-textobjects", -- OMG
			"nvim-treesitter/nvim-treesitter-context", -- Sweet
		},
	})

	-- Open cmdline in a float - don't have to look down after pressing ":"
	use({
		"folke/noice.nvim",
		requires = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify",
		},
		config = function()
			require("noice").setup({
				lsp = {
					-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
					override = {
						["vim.lsp.util.convert_input_to_markdown_lines"] = true,
						["vim.lsp.util.stylize_markdown"] = true,
						["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
					},
				},
			})
		end,
	})

	use("mbbill/undotree")

	-- Movement goodness
	use({
		"phaazon/hop.nvim",
		branch = "v2", -- optional but strongly recommended
		-- 	config = function()
		-- 		-- you can configure Hop the way you like here; see :h hop-config
		-- 		require("hop").setup()
		-- 	end,
	})

	-- I prefer using hop
	-- use("ggandor/leap.nvim")

	-- Ain't free for me no mo :(
	-- use("github/copilot.vim")

	use({
		"L3MON4D3/LuaSnip",
		-- follow latest release.
		tag = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
		-- install jsregexp (optional!:).
		run = "make install_jsregexp",
		requires = "rafamadriz/friendly-snippets",
	})

	-- File navigation
	use("stevearc/oil.nvim")
	use({
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		requires = { { "nvim-lua/plenary.nvim" } },
	})

	-- LSP crazyness
	use({
		"VonHeikemen/lsp-zero.nvim",
		branch = "v2.x",
		requires = {
			-- LSP Support
			{ "neovim/nvim-lspconfig" }, -- Required
			{ -- Optional
				"williamboman/mason.nvim",
				run = function()
					vim.cmd("MasonUpdate")
				end,
			},
			{ "williamboman/mason-lspconfig.nvim" }, -- Optional

			-- Autocompletion
			{ "hrsh7th/nvim-cmp" }, -- Required
			{ "hrsh7th/cmp-nvim-lsp" }, -- Required
			{ "L3MON4D3/LuaSnip" }, -- Required

			{ "saadparwaiz1/cmp_luasnip" },
			{ "hrsh7th/cmp-nvim-lua" },
			{ "hrsh7th/cmp-buffer" },
			{ "hrsh7th/cmp-path" },
		},
	})

	use({
		"jose-elias-alvarez/null-ls.nvim",
		requires = { "nvim-lua/plenary.nvim" },
	})

	use("jay-babu/mason-null-ls.nvim")

	-- Git stuff

	-- Copy to the clipboard a link to the current line in the current file on github
	use({
		"ruifm/gitlinker.nvim",
		requires = "nvim-lua/plenary.nvim",
		config = function()
			require("gitlinker").setup()
		end,
	})
	-- Is this man really what he seems to be?
	use("ThePrimeagen/git-worktree.nvim")
	use("tpope/vim-fugitive")

	-- Status line
	use({
		"nvim-lualine/lualine.nvim",
		requires = { "nvim-tree/nvim-web-devicons" },
	})

	-- Editing goodness
	use("tpope/vim-sleuth")
	use("tpope/vim-surround")
	use("tpope/vim-commentary")
	use("lukas-reineke/indent-blankline.nvim")
	-- Prime said this sucks. I disagree
	use({
		"windwp/nvim-autopairs",
		config = function()
			require("nvim-autopairs").setup({
				map_c_w = true,
			})
		end,
	})

	use("natecraddock/sessions.nvim")

	-- Themes
	use("folke/tokyonight.nvim")
	use({ "catppuccin/nvim", as = "catppuccin" })
end)
