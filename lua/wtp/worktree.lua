local config = require("wtp.config")

local M = {}

M.DEFAULT_BASE_DIR = "../worktrees"

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

local function git(args)
	local out = vim.system(vim.list_extend({ "git" }, args), { text = true }):wait()
	if out.code ~= 0 then
		local msg = (out.stderr ~= "" and out.stderr) or out.stdout or "unknown error"
		return nil, vim.trim(msg)
	end
	return vim.trim(out.stdout or ""), nil
end

local function is_dirty()
	local out, err = git({ "status", "--porcelain" })
	if not out then
		return nil, err
	end
	return out ~= "", nil
end

local function current_branch()
	return git({ "rev-parse", "--abbrev-ref", "HEAD" })
end

--- Convert the repository to a bare layout, moving the current branch
--- into a worktree under base_dir.
function M.to_bare(base_dir)
	base_dir = base_dir or "worktrees"

	local root, err = git({ "rev-parse", "--show-toplevel" })
	if not root then
		return nil, err
	end

	local bare, berr = git({ "rev-parse", "--is-bare-repository" })
	if not bare then
		return nil, berr
	end
	if bare == "true" then
		return nil, "repository is already bare"
	end

	local dirty, derr = is_dirty()
	if dirty == nil then
		return nil, derr
	end
	if dirty then
		return nil, "working tree is dirty; commit or stash before converting"
	end

	local branch, brerr = current_branch()
	if not branch then
		return nil, brerr
	end
	if branch == "HEAD" then
		return nil, "detached HEAD; check out a branch first"
	end

	-- 1. mark the repo bare
	local _, cerr = git({ "config", "core.bare", "true" })
	if cerr then
		return nil, cerr
	end

	-- 2. remove the old working tree files (tracked only; .git is untouched)
	local files, ferr = git({ "ls-files" })
	if not files then
		return nil, ferr
	end

	local dirs = {}
	for line in files:gmatch("[^\r\n]+") do
		os.remove(vim.fs.joinpath(root, line))
		local dir = vim.fs.dirname(line)
		while dir and dir ~= "." and dir ~= "" do
			dirs[dir] = true
			dir = vim.fs.dirname(dir)
		end
	end

	-- delete deepest-first so parents empty out before we try them
	local ordered = vim.tbl_keys(dirs)
	table.sort(ordered, function(a, b)
		return #a > #b
	end)
	for _, dir in ipairs(ordered) do
		vim.uv.fs_rmdir(vim.fs.joinpath(root, dir))
	end

	-- 3. create the worktree for the branch we were on
	local dest = vim.fs.joinpath(root, base_dir, branch)
	local _, werr = git({ "worktree", "add", dest, branch })
	if werr then
		git({ "config", "core.bare", "false" }) -- best-effort rollback
		return nil, "worktree add failed: " .. werr
	end

	return dest, nil
end

return M
