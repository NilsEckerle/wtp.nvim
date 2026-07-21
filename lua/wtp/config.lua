local M = {}

local function is_relocatable(buf)
	return vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" and not vim.bo[buf].modified
end

--- Map a buffer path from one worktree root to another.
--- Falls back to the deepest existing ancestor directory.
--- Returns nil if the buffer is outside `old_root`.
local function mapped_path(buf, old_root, new_root)
	local name = vim.api.nvim_buf_get_name(buf)
	if name:sub(1, #old_root) ~= old_root then
		return nil
	end

	local rel = name:sub(#old_root + 2)
	if rel == "" then
		return nil
	end

	local candidate = vim.fs.joinpath(new_root, rel)
	if vim.uv.fs_stat(candidate) then
		return candidate
	end

	-- walk up until something exists; new_root itself always does
	local dir = vim.fs.dirname(candidate)
	while dir and #dir >= #new_root do
		if vim.uv.fs_stat(dir) then
			return dir
		end
		dir = vim.fs.dirname(dir)
	end

	return new_root
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
