{
  config,
  lib,
  ...
}:
let
  cfg = config.custom.neovim;
  helpers = import ./lib.nix { inherit lib config; };
  inherit (helpers) mkKeymap normalKeymap;
  putKeymap =
    key: desc:
    mkKeymap [ "n" "x" ] key { __raw = ''function() require("clipboard_sync").put("${key}") end''; } {
      inherit desc;
    };
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      extraFiles."lua/clipboard_sync.lua".text = ''
        local M = {}

        local last_system = nil

        local function read_system()
          if vim.fn.has("clipboard") == 0 then
            return nil
          end
          local ok, info = pcall(vim.fn.getreginfo, "+")
          if not ok then
            return nil
          end
          return { info.regcontents or {}, info.regtype or "v" }
        end

        local function import_system()
          local now = read_system()
          if now == nil or vim.deep_equal(now, last_system) then
            return
          end
          last_system = now
          local lines = now[1]
          if #lines == 0 or (#lines == 1 and lines[1] == "") then
            return
          end
          vim.fn.setreg('"', lines, now[2])
          local ok, yanky_utils = pcall(require, "yanky.utils")
          if ok then
            require("yanky.history").push(yanky_utils.get_register_info('"'))
          end
        end

        function M.put(kind)
          if vim.v.register == '"' then
            import_system()
          end
          local mode = vim.fn.mode()
          require("yanky").put(kind, mode == "v" or mode == "V" or mode == "\22")
        end

        function M.setup()
          if (vim.env.SSH_TTY or vim.env.SSH_CONNECTION) and not vim.env.TMUX then
            local osc52 = require("vim.ui.clipboard.osc52")
            local cache = {}
            local function copy(reg)
              local send = osc52.copy(reg)
              return function(lines, regtype)
                cache[reg] = { lines, regtype }
                send(lines)
              end
            end
            local function paste(reg)
              return function()
                return cache[reg] or {}
              end
            end
            vim.g.clipboard = {
              name = "OSC 52 copy, local paste",
              copy = { ["+"] = copy("+"), ["*"] = copy("*") },
              paste = { ["+"] = paste("+"), ["*"] = paste("*") },
            }
          end

          vim.api.nvim_create_autocmd("TextYankPost", {
            group = vim.api.nvim_create_augroup("ClipboardSync", { clear = true }),
            desc = "Copy yanks, not deletes, to the system clipboard",
            callback = function()
              local event = vim.v.event
              if event.regname ~= "" or vim.fn.has("clipboard") == 0 then
                return
              end
              if event.operator == "y" then
                vim.fn.setreg("+", event.regcontents, event.regtype)
              end
              last_system = read_system()
            end,
          })
        end

        return M
      '';

      extraConfigLuaPre = ''
        require("clipboard_sync").setup()
      '';

      plugins.yanky = {
        enable = true;
        enableTelescope = true;
        settings = {
          ring.history_length = 200;
          system_clipboard.sync_with_ring = false;
          highlight = {
            on_yank = false;
            on_put = true;
            timer = 200;
          };
          picker.telescope = {
            use_default_mappings = false;
            mappings.i."<C-x>" = "mapping.delete()";
          };
        };
        luaConfig.post = ''
          require("yanky.config").options.picker.telescope.mappings.default =
            require("yanky.telescope.mapping").put("p")
        '';
      };

      keymaps = [
        (putKeymap "p" "Put after")
        (putKeymap "P" "Put before")
        (putKeymap "gp" "Put after, cursor after text")
        (putKeymap "gP" "Put before, cursor after text")
        (mkKeymap "n" "[y" "<Plug>(YankyCycleForward)" {
          desc = "Swap put for older yank";
          remap = true;
        })
        (mkKeymap "n" "]y" "<Plug>(YankyCycleBackward)" {
          desc = "Swap put for newer yank";
          remap = true;
        })
        (normalKeymap "<leader>fy" "<cmd>Telescope yank_history<CR>" { desc = "Yank history"; })
      ];
    };
  };
}
