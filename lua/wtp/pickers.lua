local config = require("wtp.config")
local worktree = require("wtp.worktree")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")

local M = {}

local displayer = entry_display.create({
	separator = "  ",
	items = {
		{ width = 30 },
		{ width = 10 },
		{ remaining = true },
	},
})

local function make_display(entry)
	local wt = entry.value
	return displayer({
		{ wt.branch, wt.current and "TelescopeResultsIdentifier" or "" },
		{ wt.status, wt.status == "managed" and "Comment" or "WarningMsg" },
		wt.path,
	})
end

local function entry_maker(wt)
	return {
		value = wt,
		display = make_display,
		ordinal = wt.branch .. " " .. wt.path,
	}
end

local function notify_err(err)
	vim.notify("wtp: " .. tostring(err), vim.log.levels.ERROR)
end

function M.switch(opts)
	opts = opts or {}
	local items, err = worktree.list()
	if not items then
		return notify_err(err)
	end

	pickers
		.new(opts, {
			prompt_title = "Worktrees",
			finder = finders.new_table({ results = items, entry_maker = entry_maker }),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(bufnr)
					if not selection then
						return
					end
					local path, rerr = worktree.resolve(selection.value)
					if not path then
						return notify_err(rerr)
					end
					config.options.on_switch(path)
				end)
				return true
			end,
		})
		:find()
end

function M.create()
	vim.ui.input({ prompt = "New worktree branch: " }, function(branch)
		if not branch or vim.trim(branch) == "" then
			return
		end
		branch = vim.trim(branch)

		local _, err = worktree.add(branch, { create = true })
		if err then
			if err:match("destination path already exists") then
				return notify_err(err)
			end
			local _, err2 = worktree.add(branch, { create = false })
			if err2 then
				return notify_err(err2)
			end
		end
		vim.notify("wtp: created " .. branch)
	end)
end

function M.delete(opts)
	opts = opts or {}
	local items, err = worktree.list()
	if not items then
		return notify_err(err)
	end

	pickers
		.new(opts, {
			prompt_title = "Delete Worktree",
			finder = finders.new_table({ results = items, entry_maker = entry_maker }),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(bufnr)
					if not selection then
						return
					end

					local wt = selection.value
					local function do_remove()
						local _, rerr = worktree.remove(wt.branch)
						if rerr then
							return notify_err(rerr)
						end
						vim.notify("wtp: removed " .. wt.branch)
					end

					if config.options.confirm_delete then
						vim.ui.select({ "yes", "no" }, {
							prompt = "Remove worktree " .. wt.branch .. "?",
						}, function(choice)
							if choice == "yes" then
								do_remove()
							end
						end)
					else
						do_remove()
					end
				end)
				return true
			end,
		})
		:find()
end

function M.init()
	vim.ui.input({
		prompt = "Worktree base_dir: ",
		default = worktree.DEFAULT_BASE_DIR,
	}, function(base_dir)
		if base_dir == nil then
			return
		end -- cancelled
		local _, err = worktree.init(vim.trim(base_dir))
		if err then
			return notify_err(err)
		end
		vim.notify("wtp: initialized .wtp.yml (base_dir: " .. vim.trim(base_dir) .. ")")
	end)
end

function M.bare()
	vim.ui.select({ "no", "yes" }, {
		prompt = "Convert this repo to a bare worktree layout?",
	}, function(choice)
		if choice ~= "yes" then
			return
		end

		vim.ui.input({
			prompt = "Base directory: ",
			default = "worktrees",
		}, function(base_dir)
			if base_dir == nil then
				return
			end
			local dest, err = worktree.to_bare(vim.trim(base_dir))
			if err then
				return notify_err(err)
			end
			vim.notify("wtp: converted to bare; worktree at " .. dest)
			config.options.on_switch(dest)
		end)
	end)
end

return M
