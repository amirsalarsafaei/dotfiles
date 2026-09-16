{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.neovim;

  helpers = import ./lib.nix { inherit lib config; };
  inherit (helpers) mkKeymap normalKeymap;

  neovimPlugins = pkgs.callPackage ../../../pkgs/neovim-plugins.nix { };
  inherit (neovimPlugins) base64Plugin platformioPlugin;

  jsDebugPath = "${pkgs.vscode-js-debug}/lib/node_modules/js-debug";
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      extraPackages = [
        pkgs.shfmt
      ]
      ++ lib.optionals cfg.features.debug [
        pkgs.delve
        pkgs.vscode-js-debug
      ];

      extraPlugins = [
        base64Plugin
      ]
      ++ lib.optionals cfg.features.debug (
        with pkgs.vimPlugins;
        [
          nvim-dap-go
          nvim-dap-vscode-js
        ]
      )
      ++ lib.optionals cfg.features.embedded [ platformioPlugin ];

      plugins = {
        conform-nvim = {
          enable = true;
          settings = {
            format_on_save = ''
              function(bufnr)
                if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                  return
                end
                if vim.bo[bufnr].filetype:match("helm") or _G.nvim_is_helm_template(bufnr) then
                  return
                end
                return { timeout_ms = 3000, lsp_format = "fallback" }
              end
            '';
            formatters_by_ft = {
              lua = [ "stylua" ];
              c = [ "clang-format" ];
              cpp = [ "clang-format" ];
              go = [
                "gofmt"
                "goimports_reviser"
              ];
              python = [
                "ruff_organize_imports"
                "ruff_format"
              ];
              rust = [ "rustfmt" ];
              sh = [ "shfmt" ];
              bash = [ "shfmt" ];
              markdown = [ "prettier" ];
              "markdown.mdx" = [ "prettier" ];
              json = [ "prettier" ];
              jsonc = [ "prettier" ];
              yaml = [ "prettier" ];
              helm = [ ];
              sql = [ "sqlfluff" ];
              proto = [ "buf" ];
            };
            formatters = {
              "clang-format".prepend_args = [
                "--fallback-style={BasedOnStyle: LLVM, IndentWidth: 4, UseTab: Never}"
              ];
              shfmt.prepend_args = [
                "-i"
                "2"
                "-ci"
              ];
              goimports_reviser.prepend_args = [
                "-company-prefixes"
                "git.divar.cloud/divar"
              ];
              sqlfluff.args.__raw = ''
                function()
                  local args = { "format", "--dialect", "postgres" }
                  if vim.fn.filereadable(vim.fn.getcwd() .. "/.sqlfluff") == 1 then
                    vim.list_extend(args, { "--config", "$ROOT/.sqlfluff" })
                  end
                  vim.list_extend(args, { "-" })
                  return args
                end
              '';
            };
          };
        };

        lint = {
          enable = true;
          lintersByFt = {
            yaml = [ "yamllint" ];
            dockerfile = [ "hadolint" ];
            nix = [ "statix" ];
            sh = [ "shellcheck" ];
            bash = [ "shellcheck" ];
            zsh = [ "shellcheck" ];
            python = [ "mypy" ];
            rust = [ "clippy" ];
          };
        };

        toggleterm = {
          enable = true;
          settings = {
            size.__raw = ''
              function(term)
                if term.direction == "horizontal" then
                  return 15
                elseif term.direction == "vertical" then
                  return vim.o.columns * 0.4
                end
              end
            '';
            hide_numbers = true;
            shade_terminals = true;
            shading_factor = 2;
            start_in_insert = true;
            insert_mappings = true;
            persist_size = true;
            close_on_exit = true;
            shell.__raw = "vim.o.shell";
            float_opts = {
              border = "curved";
              winblend = 0;
            };
            winbar.enabled = false;
          };
        };

        vim-suda.enable = true;
        venv-selector.enable = true;
        cmake-tools.enable = true;
        hex.enable = cfg.features.embedded;

        dap = lib.mkIf cfg.features.debug { enable = true; };
        dap-ui = lib.mkIf cfg.features.debug {
          enable = true;
          settings.render.max_type_length = 0;
        };
        dap-virtual-text = lib.mkIf cfg.features.debug { enable = true; };
        dap-python = lib.mkIf cfg.features.debug { enable = true; };
        dap-lldb = lib.mkIf cfg.features.debug {
          enable = true;
          settings.codelldb_path = "${pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter}/bin/codelldb";
        };

        neotest = lib.mkIf cfg.features.debug {
          enable = true;
          adapters = {
            go.enable = true;
            python.enable = true;
            jest.enable = true;
            vitest.enable = true;
          };
        };

        # https://github.com/coder/claudecode.nvim — talks to a running Claude
        # Code session over its terminal protocol (selections, diffs, @-mentions)
        # rather than shelling out a one-shot command. terminal_cmd defaults to
        # "claude", which resolves to the claudePicker wrapper on $PATH.
        claudecode = lib.mkIf cfg.features.ai {
          enable = true;
          settings.diff_opts.auto_close_on_accept = true;
        };
      };

      keymaps = [
        {
          mode = "n";
          key = "<leader>W";
          action = "<cmd>SudaWrite<CR>";
          options = {
            desc = "Write file with sudo";
            silent = true;
          };
        }
        {
          mode = "n";
          key = ",v";
          action = "<cmd>VenvSelect<CR>";
          options = {
            desc = "Select Python venv";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>tt";
          action = "<cmd>ToggleTerm direction=horizontal<CR>";
          options = {
            desc = "Terminal horizontal";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>tv";
          action = "<cmd>ToggleTerm direction=vertical size=80<CR>";
          options = {
            desc = "Terminal vertical";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>tf";
          action = "<cmd>ToggleTerm direction=float<CR>";
          options = {
            desc = "Terminal float";
            silent = true;
          };
        }
        {
          mode = [
            "n"
            "t"
          ];
          key = "<C-\\>";
          action = "<cmd>ToggleTerm<CR>";
          options = {
            desc = "Toggle terminal";
            silent = true;
          };
        }
      ]
      ++ lib.optionals cfg.features.ai [
        {
          mode = "n";
          key = "<leader>ac";
          action = "<cmd>ClaudeCode<CR>";
          options = {
            desc = "Claude Code: toggle";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>af";
          action = "<cmd>ClaudeCodeFocus<CR>";
          options = {
            desc = "Claude Code: focus";
            silent = true;
          };
        }
        {
          mode = [
            "n"
            "v"
          ];
          key = "<leader>as";
          action = "<cmd>ClaudeCodeSend<CR>";
          options = {
            desc = "Claude Code: send selection";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>aa";
          action = "<cmd>ClaudeCodeDiffAccept<CR>";
          options = {
            desc = "Claude Code: accept diff";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>ad";
          action = "<cmd>ClaudeCodeDiffDeny<CR>";
          options = {
            desc = "Claude Code: reject diff";
            silent = true;
          };
        }
      ]
      ++ lib.optionals cfg.features.embedded [
        {
          mode = "n";
          key = "<leader>pb";
          action = "<cmd>Piorun<CR>";
          options = {
            desc = "PlatformIO: Build";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>pu";
          action = "<cmd>Pioupload<CR>";
          options = {
            desc = "PlatformIO: Upload";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>pm";
          action = "<cmd>Piomonitor<CR>";
          options = {
            desc = "PlatformIO: Serial Monitor";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>pl";
          action = "<cmd>Piolog<CR>";
          options = {
            desc = "PlatformIO: Log";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>pd";
          action = "<cmd>Piodebug<CR>";
          options = {
            desc = "PlatformIO: Debug (OpenOCD)";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>hx";
          action = "<cmd>HexToggle<CR>";
          options = {
            desc = "Toggle hex view";
            silent = true;
          };
        }
      ]
      ++ [
        (mkKeymap [ "n" "v" ] "<leader>cf" {
          __raw = ''
            function()
              local bufnr = vim.api.nvim_get_current_buf()
              if vim.bo[bufnr].filetype:match("helm") or _G.nvim_is_helm_template(bufnr) then
                vim.notify("Skipping format for Helm template", vim.log.levels.WARN)
                return
              end

              require("conform").format({ timeout_ms = 3000, lsp_format = "fallback" })
            end
          '';
        } { desc = "Format buffer/selection"; })
        (normalKeymap "<leader>uf" "<cmd>FormatToggle!<CR>" { desc = "Toggle global autoformat"; })
        (normalKeymap "<leader>uF" "<cmd>FormatToggle<CR>" { desc = "Toggle buffer autoformat"; })
        (mkKeymap "x" "<leader>b" "<Plug>(FromBase64)" { desc = "Decode base64"; })
        (mkKeymap "x" "<leader>B" "<Plug>(ToBase64)" { desc = "Encode base64"; })
      ]
      ++ lib.optionals cfg.features.debug [
        (normalKeymap "<leader>rp" {
          __raw = ''function() require("dap").toggle_breakpoint() end'';
        } { desc = "Toggle breakpoint"; })
        (normalKeymap "<leader>rbc" {
          __raw = ''function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end'';
        } { desc = "Conditional breakpoint"; })
        (normalKeymap "<leader>rbl" {
          __raw = ''function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: ")) end'';
        } { desc = "Log point"; })
        (normalKeymap "<leader>rc" { __raw = ''function() require("dap").continue() end''; } {
          desc = "Continue debugging";
        })
        (normalKeymap "<leader>rs" { __raw = ''function() require("dap").close() end''; } {
          desc = "Close the debugger";
        })
        (normalKeymap "<leader>rl" { __raw = ''function() require("dap").run_last() end''; } {
          desc = "Run the last debug profile";
        })
        (normalKeymap "<leader>rj" { __raw = ''function() require("dap").down() end''; } {
          desc = "Down the stack trace";
        })
        (normalKeymap "<leader>rk" { __raw = ''function() require("dap").up() end''; } {
          desc = "Up the stack trace";
        })
        (normalKeymap "<leader>rq" { __raw = ''function() require("dapui").close() end''; } {
          desc = "Close the debugger UI";
        })
        (normalKeymap "<leader>ri" { __raw = ''function() require("dap").step_into() end''; } {
          desc = "Step into";
        })
        (normalKeymap "<leader>r0" { __raw = ''function() require("dap").step_out() end''; } {
          desc = "Step out";
        })
        (normalKeymap "<leader>ro" { __raw = ''function() require("dap").step_over() end''; } {
          desc = "Step over";
        })
        (normalKeymap "<leader>rf" {
          __raw = ''function() require("dapui").float_element("scopes", { enter = true }) end'';
        } { desc = "Float the scopes window"; })

        (normalKeymap "<leader>rn" { __raw = ''function() require("neotest").run.run() end''; } {
          desc = "Run the nearest test";
        })
        (normalKeymap "<leader>rF" {
          __raw = ''function() require("neotest").run.run(vim.fn.expand("%")) end'';
        } { desc = "Run the test file"; })
        (normalKeymap "<leader>ra" {
          __raw = ''function() require("neotest").run.run(vim.fn.getcwd()) end'';
        } { desc = "Run all tests"; })
        (normalKeymap "<leader>rd" {
          __raw = ''function() require("neotest").run.run({ strategy = "dap" }) end'';
        } { desc = "Debug the nearest test"; })
        (normalKeymap "<leader>rS" { __raw = ''function() require("neotest").run.stop() end''; } {
          desc = "Stop the test run";
        })
        (normalKeymap "<leader>ru" {
          __raw = ''function() require("neotest").summary.toggle() end'';
        } { desc = "Toggle the test summary"; })
        (normalKeymap "<leader>rw" {
          __raw = ''function() require("neotest").output_panel.toggle() end'';
        } { desc = "Toggle the test output panel"; })
      ];

      extraConfigLua = ''
        vim.api.nvim_create_autocmd("TermOpen", {
          pattern = "term://*toggleterm#*",
          callback = function()
            local buf_opts = { buffer = 0 }
            vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], buf_opts)
            vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], buf_opts)
            vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], buf_opts)
            vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], buf_opts)
            vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], buf_opts)
          end,
        })
      ''
      + lib.optionalString cfg.features.embedded ''
        do
          local ok, pio = pcall(require, "platformio")
          if ok and pio.setup then
            pio.setup({})
          end
        end
      ''
      + ''
        -- nvim-base64
        do
          local ok, base64 = pcall(require, "nvim-base64")
          if ok then
            base64.setup()
          end
        end
      ''
      + lib.optionalString cfg.features.debug ''
        do
          local dap = require("dap")
          local dap_go = require("dap-go")
          local dap_js = require("dap-vscode-js")

          dap_go.setup({
            delve = {
              initialize_timeout_sec = 30,
              path = "dlv",
            },
            dap_configurations = {
              type = "go",
            },
          })

          dap_js.setup({
            debugger_path = "${jsDebugPath}",
            adapters = { "pwa-node", "pwa-chrome", "node", "chrome" },
          })

          local js_based_languages = { "typescript", "javascript", "typescriptreact", "javascriptreact" }
          for _, language in ipairs(js_based_languages) do
            dap.configurations[language] = {
              {
                type = "pwa-node",
                request = "launch",
                name = "Launch file",
                program = "''${file}",
                cwd = "''${workspaceFolder}",
                sourceMaps = true,
              },
              {
                type = "pwa-node",
                request = "attach",
                name = "Attach",
                processId = require("dap.utils").pick_process,
                cwd = "''${workspaceFolder}",
              },
              {
                type = "pwa-chrome",
                request = "launch",
                name = 'Start Chrome with "localhost"',
                url = function()
                  local co = coroutine.running()
                  return coroutine.create(function()
                    vim.ui.input({
                      prompt = "Enter URL: ",
                      default = "http://localhost:5173",
                    }, function(url)
                      if url == nil or url == "" then
                        return
                      else
                        coroutine.resume(co, url)
                      end
                    end)
                  end)
                end,
                webRoot = "''${workspaceFolder}",
                userDataDir = "''${workspaceFolder}/.vscode/vscode-chrome-debug-userdatadir",
              },
            }
          end

          local dapui = require("dapui")
          dap.listeners.before.attach.dapui_config = function()
            dapui.open()
          end
          dap.listeners.before.launch.dapui_config = function()
            dapui.open()
          end
        end
      '';
    };
  };
}
