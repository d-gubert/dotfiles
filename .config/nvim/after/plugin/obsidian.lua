local ok, obsidian = pcall(require, "obsidian")

if not ok then
	return
end

obsidian.setup({
	workspaces = {
		{
			name = "personal",
			path = "~/dev/github.com/d-gubert/personal-obsidian-vault",
			overrides = {
				daily_notes = {
					folder = "00 Dailies",
				},
			},
		},
	},
})
