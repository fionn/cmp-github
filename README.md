# cmp-github

Completion source for issues, pull requests and users from GitHub.

## Triggers

Completion is triggered on `#` for issues and pull requests and on `@` for users.

## Installation

Ensure [`gh`](https://cli.github.com/) is installed and [authenticated](https://cli.github.com/manual/gh_auth_login).

Install this plugin, then add it as a completion source for Git commit messages with

```lua
cmp.setup.filetype("gitcommit", {
    ---@type cmp.SourceConfig[]
    sources = cmp.config.sources {
        {name = "github"}
    }
})
```
or similar.

## Alternatives

* [petertriho/cmp-git](https://github.com/petertriho/cmp-git) also provides this, and a lot more.
