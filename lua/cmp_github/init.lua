---@class (exact) Issue
---@field number integer
---@field title string
---@field state string
---@field body string
---@field createdAt string
---@field author table

---@diagnostic disable-next-line: name-style-check
local source = {}

---@type vim.SystemOpts
local system_opts = {
    text = true,
    timeout = 4000
}

---@type lsp.CompletionItem[]
local global_issues = {}
local updated_issues = false

---@type lsp.CompletionItem[]
local global_users = {}
local updated_users = false
local repo_owner = ""
local repo_name = ""

---@param out vim.SystemCompleted
local function issues_callback(out)
    if out.code ~= 0 then
        vim.schedule(function()
            vim.notify("Failed to fetch issues or PRs", vim.log.levels.ERROR)
        end)
        return
    end

    ---@type Issue[]
    local issues = vim.json.decode(assert(out.stdout))
    for _, x in ipairs(issues) do
        ---@type lsp.CompletionItem
        local issue = {
            label = string.format("#%d %s", x.number, x.title),
            sortText = tostring(1 / x.number),
            insertText = "#" .. x.number,
            detail = string.format("%s (#%d, %s)", x.title, x.number, x.state:lower()),
            documentation = string.format("Author: @%s, %s\n\n%s",
                x.author.login, x.createdAt, x.body),
            kind = 20
        }
        table.insert(global_issues, issue)
    end
end

local function get_issues()
    if updated_issues then return end
    updated_issues = true

    local issues_cmd = {
        "gh", "issue", "list", "--state", "all", "--limit", "100",
        "--json", "number,state,title,author,createdAt,body"
    }
    local issues_proc = vim.system(issues_cmd, system_opts, issues_callback)

    local prs_cmd = {
        "gh", "pr", "list", "--state", "all", "--limit", "100",
        "--json", "number,state,title,author,createdAt,body"
    }
    local prs_proc = vim.system(prs_cmd, system_opts, issues_callback)

    issues_proc:wait(system_opts.timeout)
    prs_proc:wait(system_opts.timeout)
end

---@param out vim.SystemCompleted
local function users_callback(out)
    if out.code ~= 0 then
        -- This is expected to fail when querying for collaborators in
        -- repositories the user doesn't have write access to, so we fail
        -- gracefully and return without error. This is not totally ideal, as
        -- this callback is shared with querying contributors, which we want to
        -- fail loudly on error, but there's no nice way to distinguish between
        -- the two from the callback's perspective, so just eat the error
        -- unconditionally.
        return
    end

    ---@type string[]
    local users = vim.json.decode(assert(out.stdout))
    for _, x in ipairs(users) do
        ---@type lsp.CompletionItem
        local user = {
            label = "@" .. x,
            sortText = x,
            kind = 12
        }
        table.insert(global_users, user)
    end

end

local function get_users()
    if updated_users then return end
    updated_users = true

    vim.system({"gh", "repo", "view", "--json", "owner,name"}, system_opts, function(out)
        if out.code ~= 0 then
            vim.schedule(function()
                vim.notify("Failed to resolve repository: " .. out.stderr, vim.log.levels.ERROR)
            end)
        end

        local response = vim.json.decode(assert(out.stdout))
        ---@type string
        repo_owner = response.owner.login
        ---@type string
        repo_name = response.name
    end):wait(system_opts.timeout)

    local contributors_cmd = {
        "gh", "api",
        "-H", "Accept: application/vnd.github+json",
        "-H", "X-GitHub-Api-Version: 2026-03-10",
        string.format("/repos/%s/%s/contributors?per_page=100", repo_owner, repo_name),
        "--jq", "[.[].login]"
    }
    local contributors_proc = vim.system(contributors_cmd, system_opts, users_callback)

    local collaborators_cmd = {
        "gh", "api",
        "-H", "Accept: application/vnd.github+json",
        "-H", "X-GitHub-Api-Version: 2026-03-10",
        string.format("/repos/%s/%s/collaborators?per_page=100", repo_owner, repo_name),
        "--jq", "[.[].login]"}
    local collaborators_proc = vim.system(collaborators_cmd, system_opts, users_callback)

    contributors_proc:wait(system_opts.timeout)
    if collaborators_proc:wait(system_opts.timeout).code == 0 then
        -- If we fetched collaborators then we might have added duplicates to
        -- the table.
        vim.list.unique(global_users, function(x) return x.label end)
    end
end

---@diagnostic disable-next-line
function source:is_available()
    return vim.bo.filetype == "gitcommit"
end

---@return string[]
---@diagnostic disable-next-line
function source:get_trigger_characters()
    return {"#", "@"}
end

---@return string
---@diagnostic disable-next-line
function source:get_keyword_pattern()
    return [[#\d\+\|@\w\+]]
end

---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
---@diagnostic disable-next-line
function source:complete(params, callback)
    if params.completion_context.triggerCharacter == "#"
        or params.context.cursor_before_line:match("#%d+") then
        get_issues()
        callback(global_issues)
        return
    end

    if params.completion_context.triggerCharacter == "@"
        or params.context.cursor_before_line:match("@%w+") then
        get_users()
        callback(global_users)
    end
end

return source
