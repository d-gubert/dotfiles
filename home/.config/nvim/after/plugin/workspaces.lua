local e, workspaces = pcall(require, 'workspaces')

if not e then
	return
end

local telescope = require('telescope')
local telescopeBuiltinPickers = require('telescope.builtin')
local sessions = require('sessions')

workspaces.setup({
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

telescope.load_extension('workspaces')
