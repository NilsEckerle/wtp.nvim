local M = {}

local function is_relocatable(buf)
	return vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" and not vim.bo[buf].modified
end

--- Map a buffer path from one worktree root to another.
--- Returns nil if the buffer is outside `old_root` or has no counterpart.
local function mapped_path(buf, old_root, new_root)
	local name = vim.api.nvim_buf_get_name(buf)
	if name:sub(1, #old_root) ~= old_root then
		return nil
	end

	local rel = name:sub(#old_root + 2)
	if rel == "" then
		return nil
	end

	local new_path = vim.fs.joinpath(new_root, rel)
	return vim.uv.fs_stat(new_path) and new_path or nil
end

local function relocate_buffer(buf, new_path)
	vim.api.nvim_buf_set_name(buf, new_path)
	vim.api.nvim_buf_call(buf, function()
		vim.cmd.edit()
	end)
end

local function follow_buffers(old_root, new_root)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if is_relocatable(buf) then
			local new_path = mapped_path(buf, old_root, new_root)
			if new_path then
				relocate_buffer(buf, new_path)
			end
		end
	end
end

M.defaults = {
	cmd = "wtp",
	-- called after switching worktrees
	on_switch = function(path)
		local old_root = vim.fn.getcwd()
		vim.cmd.tcd(vim.fn.fnameescape(path))
		follow_buffers(old_root, path)
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
