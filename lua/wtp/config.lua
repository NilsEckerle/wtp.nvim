local M = {}

local OIL_PREFIX = "oil://"

local function is_oil(buf)
	return vim.api.nvim_buf_get_name(buf):sub(1, #OIL_PREFIX) == OIL_PREFIX
end

local function is_relocatable(buf)
	if not vim.api.nvim_buf_is_loaded(buf) then
		return false
	end
	if is_oil(buf) then
		return true
	end
	return vim.bo[buf].buftype == "" and not vim.bo[buf].modified
end

--- Map a buffer path from one worktree root to another.
--- Falls back to the deepest existing ancestor directory.
--- Handles oil:// URLs by stripping and restoring the scheme.
--- Returns nil if the buffer is outside `old_root`.
local function mapped_path(buf, old_root, new_root)
	local name = vim.api.nvim_buf_get_name(buf)
	local oil = is_oil(buf)
	if oil then
		name = name:sub(#OIL_PREFIX + 1)
		name = name:gsub("/$", "")
	end

	if name:sub(1, #old_root) ~= old_root then
		return nil
	end

	local rel = name:sub(#old_root + 2)
	if rel == "" then
		return oil and (OIL_PREFIX .. new_root) or nil
	end

	local candidate = vim.fs.joinpath(new_root, rel)
	if not vim.uv.fs_stat(candidate) then
		local dir = vim.fs.dirname(candidate)
		while dir and #dir >= #new_root do
			if vim.uv.fs_stat(dir) then
				candidate = dir
				break
			end
			dir = vim.fs.dirname(dir)
		end
		if not vim.uv.fs_stat(candidate) then
			candidate = new_root
		end
	end

	return oil and (OIL_PREFIX .. candidate) or candidate
end

local function relocate_buffer(buf, new_path)
	local oil = new_path:sub(1, #OIL_PREFIX) == OIL_PREFIX

	if oil or vim.fn.isdirectory(new_path) == 1 then
		for _, win in ipairs(vim.fn.win_findbuf(buf)) do
			vim.api.nvim_win_call(win, function()
				vim.cmd.edit(vim.fn.fnameescape(new_path))
			end)
		end
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		return
	end

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
