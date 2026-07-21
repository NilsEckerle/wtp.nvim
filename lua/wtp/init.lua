local M = {}

function M.setup(opts)
	require("wtp.config").setup(opts)
end

M.switch = function(opts)
	require("wtp.pickers").switch(opts)
end
M.create = function()
	require("wtp.pickers").create()
end
M.delete = function(opts)
	require("wtp.pickers").delete(opts)
end

return M
