return {
    "folke/snacks.nvim",
    opts = {
        quickfile = { enabled = true },
        dashboard = {
            preset = {
                header = [[
      ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
      ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
      ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
      ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
      ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
      ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
            },
        },
        picker = {
            sources = {
                files = {
                    hidden = true,
                    ignored = false,
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
