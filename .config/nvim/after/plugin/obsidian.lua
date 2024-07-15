local ok, obsidian = pcall(require, "obsidian")

if not ok then
	return
end

obsidian.setup({
	workspaces = {
		{
			name = "personal",
			path = "~/dev/obsidian-vaults/Perosnal",
			overrides = {
				daily_notes = {
					folder = "00 Dailies",
				},
			},
		},
	},
})
