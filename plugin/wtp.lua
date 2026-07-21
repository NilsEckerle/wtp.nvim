if vim.g.loaded_wtp then
	return
end
vim.g.loaded_wtp = 1

vim.api.nvim_create_user_command("WtpSwitch", function()
	require("wtp.pickers").switch()
end, {})

vim.api.nvim_create_user_command("WtpCreate", function()
	require("wtp.pickers").create()
end, {})

vim.api.nvim_create_user_command("WtpDelete", function()
	require("wtp.pickers").delete()
end, {})

vim.api.nvim_create_user_command("WtpInit", function()
	require("wtp.pickers").init()
end, {})
