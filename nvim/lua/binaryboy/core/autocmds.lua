local augroup = vim.api.nvim_create_augroup -- Create/get autocommand group
local autocmd = vim.api.nvim_create_autocmd -- Create autocommand

-- Settings for filetypes:
--------------------------

-- Disable line length marker
augroup("setLineLength", { clear = true })
autocmd("Filetype", {
	group = "setLineLength",
	pattern = { "text", "markdown", "html", "xhtml", "javascript", "typescript" },
	command = "setlocal cc=0",
})

-- Set indentation to 2 spaces
augroup("setIndent", { clear = true })
autocmd("Filetype", {
	group = "setIndent",
	pattern = {
		"xml",
		"html",
		"xhtml",
		"css",
		"scss",
		"javascript",
		"typescript",
		"yaml",
		"lua",
		"javascriptreact",
		"typescriptreact",
	},
	command = "setlocal shiftwidth=2 tabstop=2",
})

autocmd("VimEnter", {
	callback = function()
		if vim.env.TMUX_WINDOW_NAME_PATH then
			local uv = vim.uv
			uv.spawn(vim.env.TMUX_WINDOW_NAME_PATH .. "/scripts/rename_session_windows.py", {})
		end
	end,
})

-- autocmd("VimLeave", {
-- 	callback = function()
-- 		if vim.env.TMUX_WINDOW_NAME_PATH then
-- 			vim.loop.spawn(
-- 				vim.env.TMUX_WINDOW_NAME_PATH .. "/scripts/rename_session_windows.py",
-- 				{}
-- 			)
-- 		end
-- 	end,
-- })
