# wtp.nvim

Telescope-powered Neovim wrapper around [wtp](https://github.com/satococoa/wtp) (Worktree Plus) for switching, creating, and deleting git worktrees.

## Requirements

- Neovim >= 0.10 (uses `vim.system`)
- [`wtp`](https://github.com/satococoa/wtp) on your `$PATH`
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "NilsEckerle/wtp.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  cmd = { "WtpInit", "WtpBare", "WtpSwitch", "WtpCreate", "WtpDelete" },
  keys = {
    { "<leader>wi", "<cmd>WtpInit<cr>", desc = "Init wtp config" },
    { "<leader>wb", "<cmd>WtpBare<cr>", desc = "Convert to bare layout" },
    { "<leader>ws", "<cmd>WtpSwitch<cr>", desc = "Switch worktree" },
    { "<leader>wc", "<cmd>WtpCreate<cr>", desc = "Create worktree" },
    { "<leader>wd", "<cmd>WtpDelete<cr>", desc = "Delete worktree" },
  },
  opts = {},
}
```

## Usage

| Command | Description |
| --- | --- |
| `:WtpInit` | Generate `.wtp.yml`, prompting for the worktree base directory |
| `:WtpBare` | Convert the repo to a bare layout, moving the current branch into a worktree |
| `:WtpSwitch` | Pick a worktree and change directory to it |
| `:WtpCreate` | Prompt for a branch name and create a worktree |
| `:WtpDelete` | Pick a worktree and remove it |

Lua API:

```lua
require("wtp").init()
require("wtp").bare()
require("wtp").switch()
require("wtp").create()
require("wtp").delete()
```

## Configuration

Defaults:

```lua
require("wtp").setup({
  -- executable to invoke
  cmd = "wtp",

  -- called with the resolved absolute path after selecting a worktree.
  -- the default changes the tab-local directory and relocates open buffers
  -- (including oil:// directory views) to their counterparts in the new
  -- worktree, falling back to the nearest existing parent directory.
  on_switch = function(path) ... end,

  -- ask before removing
  confirm_delete = true,

  -- extra arguments appended to `wtp add`
  add_args = {},
})
```

Overriding `on_switch` replaces the buffer-following behaviour entirely.

### Recipes

Change the global working directory instead of the tab-local one:

```lua
opts = {
  on_switch = function(path)
    vim.cmd.cd(vim.fn.fnameescape(path))
  end,
}
```

Open a file picker immediately after switching:

```lua
opts = {
  on_switch = function(path)
    vim.cmd.tcd(vim.fn.fnameescape(path))
    require("telescope.builtin").find_files({ cwd = path })
  end,
}
```

## How it works

The plugin shells out to the `wtp` CLI rather than manipulating git directly:

- `wtp init` — generates `.wtp.yml`; the plugin then patches `base_dir` to your answer
- `wtp list` — parsed for the picker
- `wtp cd <branch>` — resolves a selection to an absolute path
- `wtp add <branch>` — creates
- `wtp remove <branch>` — deletes

## Buffer following

After switching, open buffers are re-pointed at the equivalent path in the new
worktree:

- files that exist in both worktrees are reloaded in place
- files with no counterpart open the nearest existing parent directory
- `oil://` buffers follow the same rules and stay in oil
- modified buffers are left untouched

## Converting to a bare layout

`:WtpBare` restructures a normal clone into the bare layout that worktree
workflows assume:

```
repo/
├── .git/            # now bare
└── worktrees/
    └── main/        # your former working tree
```

It refuses to run if the working tree is dirty or HEAD is detached. Commit or
stash first.

**This is destructive.** It sets `core.bare`, deletes the tracked files from the
repository root, and creates a worktree for the branch you were on. Untracked
and ignored files are left in place at the root and are *not* moved into the new
worktree — move them manually afterwards if you need them.

## Known limitations

`wtp list` output is parsed as a fixed-width text table, since the CLI has no
documented machine-readable mode. Unusual branch names or additional columns in
future `wtp` releases may break parsing.

## License

MIT
