{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.custom.neovim;
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      extraPlugins = [ pkgs.vimPlugins.alpha-nvim ];

      plugins = {
        lualine = {
          enable = true;
          settings = {
            options = {
              theme = "auto";
              globalstatus = true;
              disabled_filetypes.statusline = [
                "dashboard"
                "alpha"
                "starter"
              ];
            };
            sections = {
              lualine_a = [ "mode" ];
              lualine_b = [ "branch" ];
              lualine_c = [
                "diagnostics"
                {
                  __unkeyed = "filetype";
                  icon_only = true;
                  separator = "";
                  padding = {
                    left = 1;
                    right = 0;
                  };
                }
                {
                  __unkeyed = "filename";
                  path = 1;
                  symbols = {
                    modified = "  ";
                    readonly = "";
                    unnamed = "";
                  };
                }
              ];
              lualine_x = [
                {
                  __unkeyed.__raw = ''function() return require("noice").api.status.command.get() end'';
                  cond.__raw = ''function() return package.loaded["noice"] and require("noice").api.status.command.has() end'';
                }
                {
                  __unkeyed.__raw = ''function() return require("noice").api.status.mode.get() end'';
                  cond.__raw = ''function() return package.loaded["noice"] and require("noice").api.status.mode.has() end'';
                }
                {
                  __unkeyed = "diff";
                  symbols = {
                    added = " ";
                    modified = " ";
                    removed = " ";
                  };
                }
              ];
              lualine_y = [
                "progress"
                "location"
              ];
              lualine_z = [{ __raw = ''function() return " " .. os.date("%R") end''; }];
            };
            extensions = [
              "nvim-tree"
              "toggleterm"
              "trouble"
            ];
          };
        };

        bufferline = {
          enable = true;
          settings.options = {
            mode = "tabs";
            separator_style = "slant";
          };
        };

        noice = {
          enable = true;
          settings = {
            notify.enabled = false;
            messages.enabled = false;
            lsp = {
              signature.enabled = false;
              override = {
                "vim.lsp.util.convert_input_to_markdown_lines" = true;
                "vim.lsp.util.stylize_markdown" = true;
                "cmp.entry.get_documentation" = true;
              };
            };
            presets = {
              bottom_search = true;
              command_palette = true;
              long_message_to_split = true;
              lsp_doc_border = true;
            };
          };
        };
      };

      extraConfigLua = ''
        do
          local ok, alpha = pcall(require, "alpha")
          if ok then
            local dashboard = require("alpha.themes.dashboard")

            dashboard.section.header.val = {
              "                ______________________                 ",
              "               < save the flying cows >                        ",
              "                ----------------------                 ",
              "                       \\   ^__^                        ",
              "                        \\  (xx)\\_______                        ",
              "                           (__)\\       )\\/\\                    ",
              "                            U  ||----w |                       ",
              "                               ||     ||                       ",
            }

            dashboard.section.buttons.val = {
              dashboard.button("f", " " .. " Find file", "<cmd>Telescope find_files<CR>"),
              dashboard.button("n", " " .. " New file", "<cmd>ene<CR>"),
              dashboard.button("r", " " .. " Recent files", "<cmd>Telescope oldfiles<CR>"),
              dashboard.button("g", " " .. " Find text", "<cmd>Telescope live_grep<CR>"),
              dashboard.button("c", " " .. " Config", "<cmd>e $MYVIMRC<CR>"),
              dashboard.button("s", " " .. " Restore Session", [[<cmd>lua require("persistence").load()<CR>]]),
              dashboard.button("q", " " .. " Quit", "<cmd>qa<CR>"),
            }

            for _, button in ipairs(dashboard.section.buttons.val) do
              button.opts.hl = "AlphaButtons"
              button.opts.hl_shortcut = "AlphaShortcut"
            end

            dashboard.section.header.opts.hl = "AlphaHeader"
            dashboard.section.buttons.opts.hl = "AlphaButtons"
            dashboard.section.footer.opts.hl = "AlphaFooter"

            dashboard.opts.layout[1].val = 8

            alpha.setup(dashboard.opts)
          end
        end
      '';
    };
  };
}
