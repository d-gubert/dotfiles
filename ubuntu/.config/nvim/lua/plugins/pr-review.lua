-- PR review sidebar built on Snacks: a left-hand tree of every file changed
-- vs the branch's base ref, with <CR> opening a base|working-tree diff.
-- See lua/pr_review/init.lua for the implementation.
return {
    "folke/snacks.nvim",
    keys = {
        {
            "<leader>gp",
            function()
                require("pr_review").open()
            end,
            desc = "PR Review (changed files)",
        },
        {
            "<leader>gP",
            function()
                vim.ui.input({ prompt = "PR Review base ref/commit: " }, function(base)
                    if base and base ~= "" then
                        require("pr_review").open({ base = base })
                    end
                end)
            end,
            desc = "PR Review (choose base)",
        },
    },
}
