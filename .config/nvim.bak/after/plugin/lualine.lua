local ok, lualine = pcall(require, "lualine")

if not ok then
	return
end

lualine.setup({
	extensions = { "fugitive" },
	sections = {
		lualine_c = {
			{
				"windows",
				mode = 1, -- Show window index only
				show_modified_status = false,
			},
			{
				"filename",
				path = 1, -- Show relative path
			},
		},
	},
	inactive_sections = {
		lualine_c = {
			{
				"windows",
				mode = 1, -- Show window index only
				show_modified_status = false,
			},
			{
				"filename",
				path = 1, -- Show relative path
			},
		},
	},
})
