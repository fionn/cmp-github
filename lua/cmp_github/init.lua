---@class (exact) Issue
---@field number number
---@field title string
---@field state string
---@field body string
---@field author table

---@diagnostic disable-next-line: name-style-check
local source = {}

---@type vim.SystemOpts
local system_opts = {
    text = true,
    timeout = 1000
}

---@type lsp.CompletionItem[]
local global_issues = {}

---@param out vim.SystemCompleted
local function issues_callback(out)
    if out.code ~= 0 then
        vim.schedule(function()
            vim.notify("stderr: " .. out.stderr, vim.log.levels.ERROR)
            vim.notify("stdout: " .. out.stdout, vim.log.levels.ERROR)
        end)
        return
    end

    ---@type Issue[]
    local issues = vim.json.decode(assert(out.stdout))
    for _, x in ipairs(issues) do
        ---@type lsp.CompletionItem
        local issue = {
            label = "#" .. x.number .. " " .. x.title,
            insertText = "#" .. x.number,
            detail = x.title .. " (issue #" .. x.number .. ", " .. x.state:lower() .. ")",
            documentation = "Author: @" .. x.author.login .. "\n\n" .. x.body,
            kind = 20
        }
        table.insert(global_issues, issue)
    end
end

local function get_issues()
    local cmd = {"gh", "issue", "list", "--state", "all", "--limit", "2", "--json", "number,state,title,author,body"}
    local issues_proc = vim.system(cmd, system_opts, issues_callback)
    issues_proc:wait(1000)

    vim.list.unique(global_issues, function(x) return x.insertText end)
end

---@diagnostic disable-next-line
function source:is_available()
    return vim.bo.filetype == "gitcommit"
end

---@return string[]
---@diagnostic disable-next-line
function source:get_trigger_characters()
    return {"#"}
end

---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
---@diagnostic disable-next-line
function source:complete(params, callback)
    if params.context.cursor.row < 3 then
        -- The cursor is on the subject or gap between subject and body, where
        -- we don't expect to be completing issues or pull requests, so abort.
        callback()
        return
    end

    get_issues()
    callback({items = global_issues})
end

return source
