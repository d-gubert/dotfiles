local telescopeBuiltinPickers = require('telescope.builtin')
local sessions = require('sessions')

require('workspaces').setup({
	hooks = {
		open_pre = function ()
			sessions.stop_autosave({ save = true })

			for _, buffid in ipairs(vim.api.nvim_list_bufs()) do
				vim.api.nvim_buf_delete(buffid, { force = true })
			end
		end,
		open = function ()
			if sessions.load() ~= true then
				sessions.save()
				telescopeBuiltinPickers.find_files()
			end
		end
	}
})
