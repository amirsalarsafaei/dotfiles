{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.custom.neovim;

  base64Plugin = pkgs.vimUtils.buildVimPlugin {
    pname = "nvim-base64";
    version = "d5d2f3a";
    src = pkgs.fetchFromGitHub {
      owner = "deponian";
      repo = "nvim-base64";
      rev = "d5d2f3a6787fb62f06a3f15db346ed84749b1c6b";
      hash = "sha256-zBhSQCxcFh5s1ekyoLy48IKB+nkj9JsUfz+KWSYGVYQ=";
    };
  };

  platformioPlugin = pkgs.vimUtils.buildVimPlugin {
    pname = "nvim-platformio-lua";
    version = "e65fd65";
    src = pkgs.fetchFromGitHub {
      owner = "anurag3301";
      repo = "nvim-platformio.lua";
      rev = "e65fd65565da5c1d98c568bd0cdcad16627cdb14";
      hash = "sha256-vIO+Un5BAzVU6JmHueSSRGujaTZcjfVBvh+sq/7CLgk=";
    };
  };

  jsDebugPath = "${pkgs.vscode-js-debug}/lib/node_modules/js-debug";
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      extraPackages =
        [ pkgs.shfmt ]
        ++ lib.optionals cfg.features.debug [
          pkgs.delve
          pkgs.vscode-js-debug
        ];

      extraPlugins =
        [ base64Plugin ]
        ++ lib.optionals cfg.features.debug (with pkgs.vimPlugins; [
          nvim-dap-go
          nvim-dap-vscode-js
        ])
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

        wakatime.enable = cfg.features.wakatime;
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
          mode = [ "n" "t" ];
          key = "<C-\\>";
          action = "<cmd>ToggleTerm<CR>";
          options = {
            desc = "Toggle terminal";
            silent = true;
          };
        }
      ]
      ++ lib.optionals cfg.features.embedded [
        {
          mode = "n";
          key = "<leader>pb";
          action = "<cmd>Piorun<CR>";
          options = { desc = "PlatformIO: Build"; silent = true; };
        }
        {
          mode = "n";
          key = "<leader>pu";
          action = "<cmd>Pioupload<CR>";
          options = { desc = "PlatformIO: Upload"; silent = true; };
        }
        {
          mode = "n";
          key = "<leader>pm";
          action = "<cmd>Piomonitor<CR>";
          options = { desc = "PlatformIO: Serial Monitor"; silent = true; };
        }
        {
          mode = "n";
          key = "<leader>pl";
          action = "<cmd>Piolog<CR>";
          options = { desc = "PlatformIO: Log"; silent = true; };
        }
        {
          mode = "n";
          key = "<leader>pd";
          action = "<cmd>Piodebug<CR>";
          options = { desc = "PlatformIO: Debug (OpenOCD)"; silent = true; };
        }
        {
          mode = "n";
          key = "<leader>hx";
          action = "<cmd>HexToggle<CR>";
          options = { desc = "Toggle hex view"; silent = true; };
        }
      ];

      extraConfigLua = ''
        -- conform format keymaps
        vim.keymap.set("n", "<leader>cf", function()
          local bufnr = vim.api.nvim_get_current_buf()
          if vim.bo[bufnr].filetype:match("helm") or _G.nvim_is_helm_template(bufnr) then
            vim.notify("Skipping format for Helm template", vim.log.levels.WARN)
            return
          end

          require("conform").format({ timeout_ms = 3000, lsp_format = "fallback" })
        end, { desc = "Format buffer", silent = true })

        vim.keymap.set("n", "<leader>uf", "<cmd>FormatToggle<CR>", { desc = "Toggle buffer autoformat", silent = true })
        vim.keymap.set("n", "<leader>uF", "<cmd>FormatToggle!<CR>", { desc = "Toggle global autoformat", silent = true })

        -- toggleterm terminal-mode mappings
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
        vim.keymap.set("x", "<Leader>b", "<Plug>(FromBase64)", { desc = "Decode base64" })
        vim.keymap.set("x", "<Leader>B", "<Plug>(ToBase64)", { desc = "Encode base64" })
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

          vim.keymap.set("n", "<leader>rp", dap.toggle_breakpoint, { desc = "toggle debug break points", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>rbc", function()
            dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
          end, { desc = "conditional break point", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>rbl", function()
            dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
          end, { desc = "logging break point", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>rc", dap.continue, { desc = "continue debugger", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>rs", dap.close, { desc = "closes debugger", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>rl", dap.run_last, { desc = "runs last debug profile", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>rj", dap.down, { desc = "go down in stack trace", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>rk", dap.up, { desc = "go up in stack trace", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>rq", dapui.close, { desc = "close debugger ui", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>ri", dap.step_into, { desc = "step into code", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>r0", dap.step_out, { desc = "step out of the code", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>ro", dap.step_over, { desc = "step over the code", noremap = true, silent = true })
          vim.keymap.set("n", "<leader>rf", function()
            dapui.float_element("scopes", { enter = true })
          end, { noremap = true, silent = true })
        end
      '';
    };
  };
}
