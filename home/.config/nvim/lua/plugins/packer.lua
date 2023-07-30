-- This file can be loaded by calling `lua require('plugins')` from your init.vim

-- Only required if you have packer configured as `opt`
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
	-- Packer can manage itself
	use 'wbthomason/packer.nvim'

	use {
		'nvim-telescope/telescope.nvim', tag = '0.1.2',
		-- or                            , branch = '0.1.x',
		requires = { { 'nvim-lua/plenary.nvim' } }
	}

	use {
		'nvim-treesitter/nvim-treesitter',
		run = ':TSUpdate'
	}

	use('nvim-treesitter/playground')
	use('nvim-treesitter/nvim-treesitter-textobjects') -- OMG
	use('nvim-treesitter/nvim-treesitter-context') -- sweet
	use('mbbill/undotree')

	-- Movement goodness
	use {
		'phaazon/hop.nvim',
		branch = 'v2', -- optional but strongly recommended
		config = function()
			-- you can configure Hop the way you like here; see :h hop-config
			require('hop').setup()
		end
	}

	use('github/copilot.vim')

	-- LSP crazyness
	use {
		'VonHeikemen/lsp-zero.nvim',
		branch = 'v2.x',
		requires = {
			-- LSP Support
			{ 'neovim/nvim-lspconfig' }, -- Required
			{                   -- Optional
				'williamboman/mason.nvim',
				run = function()
					vim.cmd('MasonUpdate')
				end,
			},
			{ 'williamboman/mason-lspconfig.nvim' }, -- Optional

			-- Autocompletion
			{ 'hrsh7th/nvim-cmp' }, -- Required
			{ 'hrsh7th/cmp-nvim-lsp' }, -- Required
			{ 'L3MON4D3/LuaSnip' }, -- Required

			{ 'saadparwaiz1/cmp_luasnip' },
			{ 'hrsh7th/cmp-buffer' },
			{ 'hrsh7th/cmp-path' },
		}
	}

	use({
		'jose-elias-alvarez/null-ls.nvim',
		requires = { 'nvim-lua/plenary.nvim' },
	})

	use('jay-babu/mason-null-ls.nvim')

	use {
		'ruifm/gitlinker.nvim',
		requires = 'nvim-lua/plenary.nvim',
		config = function()
			require('gitlinker').setup()
		end
	}

	-- Editing goodness
	use('tpope/vim-sleuth')
	use('tpope/vim-surround')
	use('tpope/vim-commentary')
	use {
		'windwp/nvim-autopairs',
		config = function()
			require('nvim-autopairs').setup {
				map_c_w = true,
			}
		end
	}

	-- Themes
	use('folke/tokyonight.nvim')
end)

