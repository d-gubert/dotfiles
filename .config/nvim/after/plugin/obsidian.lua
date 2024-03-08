local ok, obsidian = pcall(require, "obsidian")

if not ok then
	return
end

obsidian.setup({
	workspaces = {
		{
			name = "personal",
			path = "~/dev/obsidian-vaults/Perosnal",
		},
	},
})
