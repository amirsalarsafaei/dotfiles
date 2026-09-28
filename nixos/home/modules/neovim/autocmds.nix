{ config
, lib
, ...
}:
let
  cfg = config.custom.neovim;
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim.extraConfigLua = ''
      do
        local autocmd = vim.api.nvim_create_autocmd
        local augroup = vim.api.nvim_create_augroup

        local general = augroup("GeneralSettings", { clear = true })

        autocmd("TextYankPost", {
          group = general,
          desc = "Highlight on yank",
          callback = function()
            vim.hl.on_yank({ higroup = "Visual", timeout = 200 })
          end,
        })

        autocmd("BufReadPost", {
          group = general,
          desc = "Restore cursor position",
          callback = function(ev)
            local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
            local lcount = vim.api.nvim_buf_line_count(ev.buf)
            if mark[1] > 0 and mark[1] <= lcount then
              pcall(vim.api.nvim_win_set_cursor, 0, mark)
            end
          end,
        })

        autocmd("FocusGained", {
          group = general,
          desc = "Check for file changes",
          command = "checktime",
        })

        autocmd("VimResized", {
          group = general,
          desc = "Resize splits on window resize",
          callback = function()
            local current_tab = vim.fn.tabpagenr()
            vim.cmd("tabdo wincmd =")
            vim.cmd("tabnext " .. current_tab)
          end,
        })

        autocmd("BufWritePre", {
          group = general,
          desc = "Create parent directories on save",
          callback = function(ev)
            if ev.match:match("^%w%w+:[\\/][\\/]") then
              return
            end
            local file = vim.uv.fs_realpath(ev.match) or ev.match
            vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
          end,
        })

        local filetype = augroup("FileTypeSettings", { clear = true })

        autocmd("FileType", {
          group = filetype,
          desc = "2-space indent for web/config files",
          pattern = {
            "xml", "html", "xhtml", "css", "scss", "javascript", "typescript",
            "yaml", "lua", "javascriptreact", "typescriptreact", "nix", "json",
            "svelte", "vue", "markdown",
          },
          callback = function()
            vim.opt_local.shiftwidth = 2
            vim.opt_local.tabstop = 2
          end,
        })

        autocmd("FileType", {
          group = filetype,
          desc = "4-space indent for C/C++",
          pattern = { "c", "cpp", "objc", "objcpp", "cuda" },
          callback = function()
            vim.opt_local.shiftwidth = 4
            vim.opt_local.tabstop = 4
            vim.opt_local.expandtab = true
            vim.opt_local.cinoptions = ":0,l1,g0,N-s,E-s,(0,w1,Ws"
          end,
        })

        autocmd("FileType", {
          group = filetype,
          desc = "Enable wrap for prose",
          pattern = { "markdown", "text", "gitcommit" },
          callback = function()
            vim.opt_local.wrap = true
            vim.opt_local.linebreak = true
            vim.opt_local.spell = true
          end,
        })

        local function is_scratch_edit(path)
          if path == "" then
            return false
          end
          path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
          for _, dir in ipairs({ vim.env.TMPDIR, "/tmp", vim.env.XDG_RUNTIME_DIR }) do
            if dir and dir ~= "" then
              dir = vim.fs.normalize(dir)
              if path:sub(1, #dir + 1) == dir .. "/" then
                return true
              end
            end
          end
          return path:match("/%.git/[%u_]+_EDITMSG$") ~= nil
            or path:match("/%.git/rebase%-merge/git%-rebase%-todo$") ~= nil
        end

        autocmd("VimEnter", {
          group = general,
          desc = "Do not overwrite the project session from a scratch edit",
          callback = function()
            local args = vim.fn.argv()
            if #args == 0 then
              return
            end
            for _, arg in ipairs(args) do
              if not is_scratch_edit(arg) then
                return
              end
            end
            require("persistence").stop()
          end,
        })

        autocmd({ "BufReadPost", "BufNewFile" }, {
          group = general,
          desc = "Scratch edits: soft wrap, no autoformat",
          callback = function(ev)
            if is_scratch_edit(ev.match) then
              vim.b[ev.buf].disable_autoformat = true
              vim.opt_local.wrap = true
              vim.opt_local.linebreak = true
            end
          end,
        })

        autocmd("FileType", {
          group = filetype,
          desc = "Close with q",
          pattern = { "help", "man", "qf", "lspinfo", "checkhealth", "notify", "startuptime" },
          callback = function(ev)
            vim.bo[ev.buf].buflisted = false
            vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = ev.buf, silent = true })
          end,
        })

        local terminal = augroup("TerminalSettings", { clear = true })

        autocmd("TermOpen", {
          group = terminal,
          desc = "Terminal settings",
          callback = function()
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false
            vim.opt_local.signcolumn = "no"
          end,
        })
      end
    '';
  };
}
