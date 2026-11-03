{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.neovim;

  helpers = import ./lib.nix { inherit lib config; };
  inherit (helpers) normalKeymap;
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      extraPackages = [
        pkgs.mermaid-cli
        pkgs.imagemagick
      ];

      plugins.image = {
        enable = true;
        settings = {
          backend = "kitty";
          window_overlap_clear_enabled = true;
          integrations.markdown.download_remote_images = false;
        };
      };

      keymaps = [
        (normalKeymap "<leader>mm" {
          __raw = ''function() require("markdown-mermaid").render() end'';
        } { desc = "Render mermaid block under cursor"; })
      ];

      extraConfigLua = ''
        do
          local state = { win = nil, buf = nil, img = nil }

          local function close()
            if state.img then
              pcall(function() state.img:clear() end)
              state.img = nil
            end
            if state.win and vim.api.nvim_win_is_valid(state.win) then
              pcall(vim.api.nvim_win_close, state.win, true)
            end
            state.win = nil
            state.buf = nil
          end

          local function block_under_cursor()
            local row = vim.api.nvim_win_get_cursor(0)[1]
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            local open = nil
            for i, line in ipairs(lines) do
              if line:match("^%s*```") then
                local info = line:match("^%s*```%s*(%S+)")
                if open == nil then
                  if info == "mermaid" then
                    open = i
                  end
                else
                  if row > open and row < i then
                    return vim.list_slice(lines, open + 1, i - 1)
                  end
                  open = nil
                end
              end
            end
            return nil
          end

          local function show(path)
            local image = require("image")
            close()
            local height = math.floor(vim.o.lines * 0.75)
            local width = math.floor(vim.o.columns * 0.8)
            state.buf = vim.api.nvim_create_buf(false, true)
            state.win = vim.api.nvim_open_win(state.buf, true, {
              relative = "editor",
              row = math.floor((vim.o.lines - height) / 2),
              col = math.floor((vim.o.columns - width) / 2),
              height = height,
              width = width,
              style = "minimal",
              border = "rounded",
              title = " mermaid ",
              title_pos = "center",
            })
            vim.keymap.set("n", "q", close, { buffer = state.buf, silent = true })
            vim.api.nvim_create_autocmd("WinClosed", {
              pattern = tostring(state.win),
              once = true,
              callback = close,
            })
            state.img = image.from_file(path, {
              window = state.win,
              buffer = state.buf,
              max_width_window_percentage = 100,
              max_height_window_percentage = 100,
            })
            if state.img then
              state.img:render()
            else
              vim.notify("image.nvim could not load " .. path, vim.log.levels.ERROR)
            end
          end

          local function render()
            local content = block_under_cursor()
            if not content then
              vim.notify("Cursor is not inside a mermaid block", vim.log.levels.WARN)
              return
            end
            local dir = vim.fn.stdpath("cache") .. "/mermaid"
            vim.fn.mkdir(dir, "p")
            local hash = vim.fn.sha256(table.concat(content, "\n"))
            local png = dir .. "/" .. hash .. ".png"
            if vim.fn.filereadable(png) == 1 then
              show(png)
              return
            end
            local mmd = dir .. "/" .. hash .. ".mmd"
            vim.fn.writefile(content, mmd)
            vim.notify("Rendering mermaid diagram...")
            vim.system(
              { "mmdc", "-i", mmd, "-o", png, "-t", "dark", "-b", "transparent", "-s", "2" },
              { text = true },
              function(res)
                if res.code ~= 0 then
                  vim.schedule(function()
                    vim.notify("mmdc failed:\n" .. (res.stderr or res.stdout or ""), vim.log.levels.ERROR)
                  end)
                  return
                end
                vim.schedule(function() show(png) end)
              end
            )
          end

          package.loaded["markdown-mermaid"] = { render = render, close = close }
        end
      '';
    };
  };
}
