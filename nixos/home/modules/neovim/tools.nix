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
          autoCmd.event = [
            "BufReadPost"
            "BufWritePost"
            "InsertLeave"
          ];
          lintersByFt = {
            yaml = [ "yamllint" ];
            dockerfile = [ "hadolint" ];
            nix = [ "statix" ];
            sh = [ "shellcheck" ];
            bash = [ "shellcheck" ];
            python = [ "mypy" ];
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
          settings.codelldb_path = lib.getExe' pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter "codelldb";
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

        claudecode = lib.mkIf cfg.features.ai {
          enable = true;
          settings.diff_opts.auto_close_on_accept = true;
        };
      };

      keymaps = [
        (normalKeymap "<leader>W" "<cmd>SudaWrite<CR>" { desc = "Write file with sudo"; })
        (normalKeymap ",v" "<cmd>VenvSelect<CR>" { desc = "Select Python venv"; })
        (normalKeymap "<leader>tt" "<cmd>ToggleTerm direction=horizontal<CR>" {
          desc = "Terminal horizontal";
        })
        (normalKeymap "<leader>tv" "<cmd>ToggleTerm direction=vertical size=80<CR>" {
          desc = "Terminal vertical";
        })
        (normalKeymap "<leader>tf" "<cmd>ToggleTerm direction=float<CR>" { desc = "Terminal float"; })
        (mkKeymap [ "n" "t" ] "<C-\\>" "<cmd>ToggleTerm<CR>" { desc = "Toggle terminal"; })
      ]
      ++ lib.optionals cfg.features.ai [
        (normalKeymap "<leader>ac" "<cmd>ClaudeCode<CR>" { desc = "Claude Code: toggle"; })
        (normalKeymap "<leader>af" "<cmd>ClaudeCodeFocus<CR>" { desc = "Claude Code: focus"; })
        (mkKeymap [ "n" "v" ] "<leader>as" "<cmd>ClaudeCodeSend<CR>" {
          desc = "Claude Code: send selection";
        })
        (normalKeymap "<leader>aa" "<cmd>ClaudeCodeDiffAccept<CR>" { desc = "Claude Code: accept diff"; })
        (normalKeymap "<leader>ad" "<cmd>ClaudeCodeDiffDeny<CR>" { desc = "Claude Code: reject diff"; })
      ]
      ++ lib.optionals cfg.features.embedded [
        (normalKeymap "<leader>pb" "<cmd>Piorun<CR>" { desc = "PlatformIO: Build"; })
        (normalKeymap "<leader>pu" "<cmd>Pioupload<CR>" { desc = "PlatformIO: Upload"; })
        (normalKeymap "<leader>pm" "<cmd>Piomonitor<CR>" { desc = "PlatformIO: Serial Monitor"; })
        (normalKeymap "<leader>pl" "<cmd>Piolog<CR>" { desc = "PlatformIO: Log"; })
        (normalKeymap "<leader>pd" "<cmd>Piodebug<CR>" { desc = "PlatformIO: Debug (OpenOCD)"; })
        (normalKeymap "<leader>hx" "<cmd>HexToggle<CR>" { desc = "Toggle hex view"; })
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
            local splits = require("smart-splits")
            vim.keymap.set("t", "<C-h>", splits.move_cursor_left, buf_opts)
            vim.keymap.set("t", "<C-j>", splits.move_cursor_down, buf_opts)
            vim.keymap.set("t", "<C-k>", splits.move_cursor_up, buf_opts)
            vim.keymap.set("t", "<C-l>", splits.move_cursor_right, buf_opts)
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
          dap.listeners.before.event_terminated.dapui_config = function()
            dapui.close()
          end
          dap.listeners.before.event_exited.dapui_config = function()
            dapui.close()
          end
        end
      '';
    };
  };
}
