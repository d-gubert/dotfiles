return {
    "folke/snacks.nvim",
    opts = {
        quickfile = { enabled = true },
        picker = {
            sources = {
                files = {
                    hidden = true,
                    ignored = true,
                    exclude = { "node_modules", ".git" },
                },
                explorer = {
                    hidden = true,
                    ignored = true,
                },
            },
        },
    },
}
