local M = {}

M.defaults = {
	cmd = "wtp",
	-- called after switching worktrees
	on_switch = function(path)
		vim.cmd.tcd(vim.fn.fnameescape(path))
	end,
	-- confirm before removing a worktree
	confirm_delete = true,
	-- extra args passed to `wtp add`
	add_args = {},
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
