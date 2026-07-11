-- PR review sidebar: shows a tree of files changed vs a base ref (like a PR diff)
-- and opens a left/right diff (base | working tree) when you act on a file.
--
-- Relies on Snacks (folke/snacks.nvim) for the sidebar picker UI and its
-- built-in "file" formatter/tree renderer, the same building blocks used by
-- lazyvim.plugins.extras.editor.snacks_explorer.

local M = {}

local base_refs = { "origin/HEAD", "origin/main", "origin/master", "main", "master" }

-- winid of the "base" pane we keep reusing for diffs, per tabpage
local diff_wins = {}

---@param args string[]
---@param cwd string
---@return string? stdout
local function git(args, cwd)
    local result = vim.system(vim.list_extend({ "git" }, args), { cwd = cwd, text = true }):wait()
    if result.code ~= 0 then
        return nil
    end
    return result.stdout
end

--- Finds the commit the current branch diverged from, trying common
--- upstream/default branch names in order. Falls back to HEAD (i.e. just
--- uncommitted changes) if none are found.
---@param cwd string
---@return string
function M.detect_base(cwd)
    for _, ref in ipairs(base_refs) do
        if git({ "rev-parse", "--verify", "--quiet", ref }, cwd) then
            local merge_base = git({ "merge-base", "HEAD", ref }, cwd)
            if merge_base then
                return vim.trim(merge_base)
            end
        end
    end
    return "HEAD"
end

--- Maps every changed path (relative to `cwd`) to its git status (xy, in the
--- format `Snacks.picker.source.git`'s formatters expect) and the path to use
--- when looking up the base content (differs for renames).
---@param cwd string
---@param base string
---@return table<string, { xy: string, base_path: string }>
local function status_map(cwd, base)
    local statuses = {}

    local diff = git({ "diff", "--name-status", "--no-color", "-z", base }, cwd)
    if diff then
        local parts = vim.split(diff, "\0", { plain = true, trimempty = true })
        local i = 1
        while i <= #parts do
            local letter = parts[i]:sub(1, 1)
            letter = letter == "T" and "M" or letter
            if letter == "R" or letter == "C" then
                local old_path, new_path = parts[i + 1], parts[i + 2]
                statuses[new_path] = { xy = " " .. letter, base_path = old_path }
                i = i + 3
            else
                local path = parts[i + 1]
                statuses[path] = { xy = " " .. letter, base_path = path }
                i = i + 2
            end
        end
    end

    local porcelain = git({ "status", "--porcelain=v1", "-uall", "--no-renames", "-z" }, cwd)
    if porcelain then
        for _, entry in ipairs(vim.split(porcelain, "\0", { plain = true, trimempty = true })) do
            local xy, path = entry:match("^(..) (.+)$")
            if xy == "??" then
                statuses[path] = { xy = "??", base_path = path }
            end
        end
    end

    return statuses
end

--- Builds a flat, depth-first list of tree items (directories + files) for
--- every changed path, wired up with `parent`/`last` so Snacks' generic tree
--- formatter can draw the connectors.
---@param cwd string
---@param base string
---@return table[]
function M.build_items(cwd, base)
    local statuses = status_map(cwd, base)
    local paths = vim.tbl_keys(statuses)
    table.sort(paths)

    local items = {}
    local dirs = {}
    local children = {}

    local function link(item, parent_key)
        local group = children[parent_key]
        if not group then
            group = {}
            children[parent_key] = group
        end
        if group[#group] then
            group[#group].last = false
        end
        item.last = true
        group[#group + 1] = item
    end

    local function get_dir(relpath)
        if relpath == "" then
            return nil
        end
        if dirs[relpath] then
            return dirs[relpath]
        end
        local parent_path = relpath:match("^(.*)/[^/]+$") or ""
        local parent_item = parent_path ~= "" and get_dir(parent_path) or nil
        local item = {
            file = cwd .. "/" .. relpath,
            text = relpath,
            dir = true,
            open = true,
            parent = parent_item,
        }
        dirs[relpath] = item
        items[#items + 1] = item
        link(item, parent_item or "")
        return item
    end

    for _, rel in ipairs(paths) do
        local dirpath = rel:match("^(.*)/[^/]+$") or ""
        local parent_item = dirpath ~= "" and get_dir(dirpath) or nil
        local info = statuses[rel]
        local item = {
            file = cwd .. "/" .. rel,
            text = rel,
            dir = false,
            cwd = cwd,
            base = base,
            base_path = info.base_path,
            status = info.xy,
            parent = parent_item,
        }
        items[#items + 1] = item
        link(item, parent_item or "")
    end

    return items
end

---@param cwd string
---@param base string
---@param rel string
---@return integer bufnr
local function get_base_buf(cwd, base, rel)
    local name = ("prreview://%s/%s"):format(base, rel)
    local buf = vim.fn.bufnr(name)
    if buf == -1 or not vim.api.nvim_buf_is_valid(buf) then
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, name)
        local content = git({ "show", base .. ":" .. rel }, cwd)
        local lines = content and vim.split(content, "\n") or {}
        if lines[#lines] == "" then
            lines[#lines] = nil
        end
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local ft = vim.filetype.match({ filename = rel })
        if ft then
            vim.bo[buf].filetype = ft
        end
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].swapfile = false
        vim.bo[buf].modifiable = false
        vim.bo[buf].readonly = true
    end
    return buf
end

--- Opens (or reuses) a left/right diff in the picker's main window: base
--- content on the left, the current working-tree file on the right.
---@param picker snacks.Picker
---@param item table?
local function open_diff(picker, item)
    if not item or item.dir then
        return
    end

    vim.api.nvim_set_current_win(picker.main)
    vim.cmd.edit(vim.fn.fnameescape(item.file))
    local right_win = vim.api.nvim_get_current_win()

    local tab = vim.api.nvim_get_current_tabpage()
    local left_win = diff_wins[tab]
    if left_win and vim.api.nvim_win_is_valid(left_win) then
        vim.api.nvim_win_call(left_win, function()
            vim.cmd.diffoff()
        end)
    else
        vim.cmd("leftabove vertical new")
        left_win = vim.api.nvim_get_current_win()
        diff_wins[tab] = left_win
    end
    vim.api.nvim_win_call(right_win, function()
        vim.cmd.diffoff()
    end)

    local base_buf = get_base_buf(item.cwd, item.base, item.base_path or item.text)
    vim.api.nvim_win_set_buf(left_win, base_buf)

    vim.api.nvim_win_call(left_win, function()
        vim.cmd.diffthis()
    end)
    vim.api.nvim_win_call(right_win, function()
        vim.cmd.diffthis()
    end)

    vim.api.nvim_set_current_win(right_win)
end

---@param opts? { base?: string }
function M.open(opts)
    opts = opts or {}

    -- re-focus rather than re-create: confirming a file moves focus into the
    -- diff, so pressing the keymap again should bring you back to the list.
    -- an explicit base always starts a fresh picker instead.
    local existing = Snacks.picker.get({ source = "pr_review" })[1]
    if existing and not existing.closed then
        if opts.base then
            existing:close()
        else
            existing:focus()
            return
        end
    end

    local cwd = Snacks.git.get_root(0)
    if not cwd then
        Snacks.notify.error("Not inside a git repository", { title = "PR Review" })
        return
    end

    local base = opts.base or M.detect_base(cwd)

    Snacks.picker.pick({
        source = "pr_review",
        title = "PR Review (" .. base:sub(1, 8) .. ")",
        finder = function()
            return M.build_items(cwd, base)
        end,
        format = "file",
        matcher = { sort_empty = false },
        formatters = { file = { filename_only = true } },
        layout = { preset = "sidebar", preview = false },
        focus = "list",
        auto_close = false,
        jump = { close = false },
        confirm = function(picker, item)
            open_diff(picker, item)
        end,
        win = {
            list = {
                keys = {
                    ["u"] = function(picker)
                        picker:find()
                    end,
                },
            },
        },
    })
end

return M
