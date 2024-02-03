local lsp = require("lsp-zero").preset({})
local nvim_lsp = require("lspconfig")

lsp.ensure_installed({
	"tsserver",
	"denols",
	"gopls",
	"lua_ls",
	"rust_analyzer",
})

lsp.on_attach(function(client, bufnr)
	lsp.default_keymaps({ buffer = bufnr })

	local getOpts = function(desc)
		return {
			buffer = bufnr,
			remap = false,
			desc = desc,
		}
	end

	vim.keymap.set("n", "gd", vim.lsp.buf.definition, getOpts("Go to definition"))
	vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, getOpts("Go to type definition"))
	vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, getOpts("Previous diagnostic"))
	vim.keymap.set("n", "]d", vim.diagnostic.goto_next, getOpts("Next diagnostic"))
	vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, getOpts("Code Actions"))
	vim.keymap.set("n", "<leader>cm", vim.lsp.buf.rename, getOpts("Rename symbol"))
	vim.keymap.set({ "n", "x" }, "<leader>cx", function()
		vim.lsp.buf.format({ async = true })
	end, getOpts("Run LSP formatter"))
	vim.keymap.set("i", "<C-k>", vim.lsp.buf.signature_help, getOpts("Signature Help"))
end)

nvim_lsp.lua_ls.setup(lsp.nvim_lua_ls())

nvim_lsp.denols.setup({
	root_dir = nvim_lsp.util.root_pattern("deno.json", "deno.jsonc"),
})

nvim_lsp.tsserver.setup({
	root_dir = nvim_lsp.util.root_pattern("package.json"),
	single_file_support = false,
})

lsp.setup()

-- Make sure to configure cmp AFTER lsp-zero
local cmp = require("cmp")

cmp.setup({
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
	snippet = {
		-- REQUIRED - you must specify a snippet engine
		expand = function(args)
			-- vim.fn["vsnip#anonymous"](args.body) -- For `vsnip` users.
			require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
			-- require('snippy').expand_snippet(args.body) -- For `snippy` users.
			-- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
		end,
	},
	mapping = cmp.mapping.preset.insert({
		["<Tab>"] = nil,
		["<S-Tab>"] = nil,
		["<C-m>"] = cmp.mapping.confirm(),
	}),
	preselect = cmp.PreselectMode.Item,
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "nvim_lua" },
		{ name = "luasnip" },
		{ name = "path" },
	}, {
		{ name = "buffer" },
	}),
})

-- If you want insert `(` after select function or method item
local ok, cmp_autopairs = pcall(require,"nvim-autopairs.completion.cmp")

if ok then
	cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
end

vim.diagnostic.config({
	virtual_text = true,
})
