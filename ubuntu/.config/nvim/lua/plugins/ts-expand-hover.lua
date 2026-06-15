-- TypeScript-only mapping to avoid conflicts with other plugins that map K
-- vim.api.nvim_create_autocmd("FileType", {
-- 	pattern = { "typescript", "typescriptreact" },
-- 	callback = function(ev)
-- 		vim.notify('Expandable hover registered')
-- 		local hover = function ()
-- 			vim.notify('Expandable hover called');
-- 			return require("ts_expand_hover").hover()
-- 		end
-- 		vim.keymap.set("n", "K", hover, {
-- 			buffer = ev.buf,
-- 			desc = "TypeScript expandable hover",
-- 			remap = true
-- 		})
-- 	end,
-- })

return {
	"nemanjamalesija/ts-expand-hover.nvim",
	ft = { "typescript", "typescriptreact" },
	config = function ()
		require("ts_expand_hover").setup({
			keymaps = { hover = '<leader>h' }
		})
	end
}
