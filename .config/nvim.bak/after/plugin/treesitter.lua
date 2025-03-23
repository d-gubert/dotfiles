require("nvim-treesitter.configs").setup({
	-- A list of parser names, or "all" (the five listed parsers should always be installed)
	ensure_installed = { "nu", "lua", "javascript", "typescript", "tsx", "query", "rust", "go", "markdown", "markdown_inline" },

	-- Install parsers synchronously (only applied to `ensure_installed`)
	sync_install = false,

	-- Automatically install missing parsers when entering buffer
	-- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
	auto_install = true,

	-- List of parsers to ignore installing (for "all")
	-- ignore_install = { "javascript" },

	---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
	-- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

	highlight = {
		enable = true,

		-- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
		-- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
		-- the name of the parser)
		-- list of language that will be disabled
		--disable = { "c", "rust" },
		-- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
		--disable = function(lang, buf)
		--    local max_filesize = 100 * 1024 -- 100 KB
		--    local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
		--    if ok and stats and stats.size > max_filesize then
		--        return true
		--    end
		--end,

		-- Setting this to true will run `:h syntax` and tree-sitter at the same time.
		-- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
		-- Using this option may slow down your editor, and you may see some duplicate highlights.
		-- Instead of true it can also be a list of languages
		additional_vim_regex_highlighting = false,
	},

	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "<leader>ln",
			node_incremental = "<C-k>",
			scope_incremental = "<C-K>",
			node_decremental = "<C-j>",
		},
	},

	indent = {
		enable = true,
	},

	-- Treesitter Text objects baby!!
	textobjects = {
		lsp_interop = {
			enable = true,
			border = "rounded",
			floating_preview_opts = {},
			peek_definition_code = {
				["<leader>pf"] = "@function.outer",
				["<leader>pF"] = "@class.outer",
			},
		},
		select = {
			enable = true,
			lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
			keymaps = {
				-- You can use the capture groups defined in textobjects.scm
				["=a"] = { query = "@assignment.outer", desc = "Select outer assignment" },
				["=i"] = { query = "@assignment.inner", desc = "Select inner assignment" },
				["=l"] = { query = "@assignment.lhs", desc = "Select assignment left-hand part" },
				["=r"] = { query = "@assignment.rhs", desc = "Select assignment right-hand part" },

				["a:"] = { query = "@statement.outer", desc = "Select outer statement" },
				["i:"] = { query = "@statement.inner", desc = "Select inner statement" },

				["a;"] = { query = "@comment.outer", desc = "Select outer comment" },
				["i;"] = { query = "@comment.inner", desc = "Select inner comment" },

				["ai"] = { query = "@conditional.outer", desc = "Select outer conditional" },
				["ii"] = { query = "@conditional.inner", desc = "Select inner conditional" },

				["a'"] = { query = "@string.outer", desc = "Select outer string" },
				["i'"] = { query = "@string.inner", desc = "Select inner string" },

				["ab"] = { query = "@block.outer", desc = "Select outer block" },
				["ib"] = { query = "@block.inner", desc = "Select inner block" },

				["aa"] = { query = "@parameter.outer", desc = "Select outer argument/parameter" },
				["ia"] = { query = "@parameter.inner", desc = "Select inner argument/parameter" },

				["af"] = { query = "@function.outer", desc = "Select outer function body" },
				["if"] = { query = "@function.inner", desc = "Select inner function body" },

				["ac"] = { query = "@call.outer", desc = "Select outer function call" },
				["ic"] = { query = "@call.inner", desc = "Select inner function call" },
			},
		},
		move = {
			enable = true,
			set_jumps = true, -- whether to set jumps in the jumplist
			goto_next_start = {
				["]m"] = "@function.outer",
				["]c"] = "@class.outer",
				["]b"] = "@block.outer",
				["]a"] = "@parameter.outer",
			},
			goto_next_end = {
				["]M"] = "@function.outer",
				["]C"] = "@class.outer",
				["]B"] = "@block.outer",
				["]A"] = "@parameter.outer",
			},
			goto_previous_start = {
				["[m"] = "@function.outer",
				["[c"] = "@class.outer",
				["[b"] = "@block.outer",
				["[a"] = "@parameter.outer",
			},
			goto_previous_end = {
				["[M"] = "@function.outer",
				["[C"] = "@class.outer",
				["[B"] = "@block.outer",
				["[A"] = "@parameter.outer",
			},
		},
		-- Not sure I want this?
		-- swap = {
		-- 	enable = true,
		-- 	swap_next = {
		-- 		['<leader>a'] = '@parameter.inner',
		-- 	},
		-- 	swap_previous = {
		-- 		['<leader>A'] = '@parameter.inner',
		-- 	},
		-- },
	},
})

local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")

-- Repeat movement with ; and ,
-- ensure ; goes forward and , goes backward regardless of the last direction
-- vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next, { desc = "Treesitter: Repeat last move forward" })
-- vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous, { desc = "Treesitter: Repeat last move backward" })

-- vim way: ; goes to the direction you were moving.
vim.keymap.set(
	{ "n", "x", "o" },
	";",
	ts_repeat_move.repeat_last_move,
	{ desc = "Treesitter: Repeat last move forward" }
)
vim.keymap.set(
	{ "n", "x", "o" },
	",",
	ts_repeat_move.repeat_last_move_opposite,
	{ desc = "Treesitter: Repeat last move backward" }
)

-- Optionally, make builtin f, F, t, T also repeatable with ; and ,
vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f, { desc = "Treesitter: Repeat f movement" })
vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F, { desc = "Treesitter: Repeat F movement" })
vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t, { desc = "Treesitter: Repeat t movement" })
vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T, { desc = "Treesitter: Repeat T movement" })

-- require("treesitter-context").setup()

vim.keymap.set("n", "[[", function()
	require("treesitter-context").go_to_context()
end, { silent = true, desc = "Treesitter: Go to context above" })
