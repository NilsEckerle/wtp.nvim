local config = require("wtp.config")

local M = {}

local function run(args)
	local cmd = vim.list_extend({ config.options.cmd or "wtp" }, args)
	local out = vim.system(cmd, { text = true }):wait()
	if out.code ~= 0 then
		local msg = (out.stderr ~= "" and out.stderr) or out.stdout or "unknown error"
		return nil, vim.trim(msg)
	end
	return out.stdout or "", nil
end

--- Parse the fixed-width table emitted by `wtp list`.
--- Columns: PATH BRANCH STATUS HEAD
function M.list()
	local out, err = run({ "list" })
	if not out then
		return nil, err
	end

	local items = {}
	local past_sep = false

	for line in out:gmatch("[^\r\n]+") do
		if line:match("^%-%-%-%-") then
			past_sep = true
		elseif past_sep and vim.trim(line) ~= "" then
			local fields = {}
			for field in line:gmatch("%S+") do
				fields[#fields + 1] = field
			end
			-- BRANCH may be "(no branch)" -> two tokens; detect and merge
			if fields[2] == "(no" and fields[3] == "branch)" then
				table.remove(fields, 3)
				fields[2] = "(no branch)"
			end
			if #fields >= 3 then
				items[#items + 1] = {
					path = fields[1],
					branch = fields[2],
					status = fields[3],
					head = fields[4] or "",
					current = fields[1]:match("%*$") ~= nil,
				}
			end
		end
	end

	return items, nil
end

--- Resolve a worktree entry to an absolute path via `wtp cd`.
function M.resolve(entry)
	local target = entry.branch ~= "(no branch)" and entry.branch or entry.path
	local out, err = run({ "cd", target })
	if not out then
		return nil, err
	end
	return vim.trim(out), nil
end

function M.add(branch, opts)
	opts = opts or {}
	local args = { "add" }
	if opts.create then
		table.insert(args, "-b")
		table.insert(args, branch)
	end
	vim.list_extend(args, config.options.add_args or {})
	if not opts.create then
		table.insert(args, branch)
	end
	local out, err = run(args)
	if not out then
		return nil, err
	end
	return vim.trim(out), nil
end

function M.remove(branch)
	local out, err = run({ "remove", branch })
	if not out then
		return nil, err
	end
	return vim.trim(out), nil
end

local function git_root()
	local out = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait()
	if out.code ~= 0 then
		return nil
	end
	local root = vim.trim(out.stdout or "")
	return root ~= "" and root or nil
end

function M.init(base_dir)
	local out, err = run({ "init" })
	if not out then
		return nil, err
	end

	if not base_dir or base_dir == "" then
		return vim.trim(out), nil
	end

	local root = git_root()
	if not root then
		return nil, "not inside a git repository"
	end

	local path = vim.fs.joinpath(root, ".wtp.yml")
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return nil, "could not read " .. path
	end

	local replaced = false
	for i, line in ipairs(lines) do
		if line:match("^%s*base_dir:") then
			lines[i] = line:gsub("(base_dir:).*", "%1 " .. base_dir)
			replaced = true
			break
		end
	end
	if not replaced then
		return nil, "base_dir key not found in .wtp.yml"
	end

	vim.fn.writefile(lines, path)
	return vim.trim(out), nil
end

M.DEFAULT_BASE_DIR = "../worktrees"

return M
