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
      extraPlugins = [ pkgs.vimPlugins.nvim-lsp-file-operations ];

      keymaps = [
        (normalKeymap "<leader>uh" {
          __raw = ''function() require("snacks").toggle.inlay_hints():toggle() end'';
        } { desc = "Toggle inlay hints"; })
      ];

      plugins = {
        lazydev = {
          enable = true;
          settings.library = [
            {
              path = "${pkgs.vimPlugins.luvit-meta}/library";
              words = [ "vim%.uv" ];
            }
          ];
        };
        fidget.enable = true;
        rustaceanvim = {
          enable = true;
          settings.server.default_settings.rust-analyzer = {
            check.command = "clippy";
            procMacro.enable = true;
          };
        };
        crates = {
          enable = true;
          settings.lsp = {
            enabled = true;
            actions = true;
            completion = true;
            hover = true;
          };
        };
        schemastore = {
          enable = true;
          json.enable = true;
          yaml.enable = false;
        };
        nvim-lightbulb = {
          enable = true;
          settings = {
            sign.enabled = true;
            autocmd.enabled = true;
          };
        };
        lsp = {
          enable = true;
          inlayHints = true;
          servers = {
            lua_ls = {
              enable = true;
              settings.Lua = {
                diagnostics.globals = [ "vim" ];
                completion.callSnippet = "Replace";
                runtime.version = "LuaJIT";
              };
            };
            gopls = {
              enable = true;
              settings.gopls = {
                codelenses = {
                  gc_details = true;
                  generate = true;
                  regenerate_cgo = true;
                  run_govulncheck = true;
                  test = true;
                  tidy = true;
                  upgrade_dependency = true;
                };
                hints = {
                  assignVariableTypes = true;
                  compositeLiteralFields = true;
                  compositeLiteralTypes = true;
                  constantValues = true;
                  functionTypeParameters = true;
                  parameterNames = true;
                  rangeVariableTypes = true;
                };
                analyses = {
                  nilness = true;
                  unusedparams = true;
                  unusedwrite = true;
                  useany = true;
                  yield = true;
                  waitgroup = true;
                };
                staticcheck = true;
                directoryFilters = [
                  "-.git"
                  "-.vscode"
                  "-.idea"
                  "-.vscode-test"
                  "-node_modules"
                  "-.nvim"
                ];
                semanticTokens = true;
              };
            };
            golangci_lint_ls.enable = true;
            nixd = {
              enable = true;
              settings = {
                nixpkgs.expr = "import ${pkgs.path} { }";
                formatting.command = [ "nixfmt" ];
              };
            };
            pyright.enable = true;
            yamlls = {
              enable = true;
              settings.yaml = {
                validate = true;
                schemas.kubernetes = [
                  "k8s**.yaml"
                  "kube*/*.yaml"
                ];
              };
            };
            jsonls.enable = true;
            helm_ls.enable = true;
            taplo.enable = true;
            ts_ls.enable = true;
            marksman.enable = true;
            cssls.enable = true;
            html.enable = true;
            dockerls.enable = true;
            docker_compose_language_service.enable = true;
            bashls.enable = true;
            sqls.enable = true;
            systemd_ls.enable = true;
            clangd = {
              enable = true;
              filetypes = [
                "c"
                "cpp"
                "objc"
                "objcpp"
                "cuda"
              ];
              cmd = [
                "clangd"
                "--background-index"
                "--clang-tidy"
                "--fallback-style={BasedOnStyle: LLVM, IndentWidth: 4, UseTab: Never}"
                "--header-insertion=iwyu"
                "--pch-storage=memory"
              ];
              extraOptions.init_options = {
                clangdFileStatus = true;
                usePlaceholders = true;
                completeUnimported = true;
              };
            };
          };
          keymaps = {
            diagnostic = {
              "<leader>cd" = "open_float";
              "<leader>cq" = "setloclist";
            };
            extra = [
              {
                mode = "n";
                key = "[d";
                action.__raw = "function() vim.diagnostic.jump({ count = -1, float = true }) end";
                options.desc = "Previous diagnostic";
              }
              {
                mode = "n";
                key = "]d";
                action.__raw = "function() vim.diagnostic.jump({ count = 1, float = true }) end";
                options.desc = "Next diagnostic";
              }
              {
                mode = "n";
                key = "<leader>cl";
                action.__raw = "vim.lsp.codelens.run";
                options.desc = "Run code lens";
              }
            ];
            lspBuf = {
              gd = "definition";
              gD = "declaration";
              gr = "references";
              gi = "implementation";
              gy = "type_definition";
              K = "hover";
              gs = "signature_help";
              "<leader>cr" = "rename";
              "<leader>ca" = {
                action = "code_action";
                mode = [
                  "n"
                  "v"
                ];
              };
            };
          };
        };
      };

      extraConfigLua = ''
        vim.diagnostic.config({
          virtual_text = {
            spacing = 4,
            prefix = "●",
          },
          signs = {
            text = {
              [vim.diagnostic.severity.ERROR] = " ",
              [vim.diagnostic.severity.WARN] = " ",
              [vim.diagnostic.severity.HINT] = "󰠠 ",
              [vim.diagnostic.severity.INFO] = " ",
            },
          },
          underline = true,
          update_in_insert = false,
          severity_sort = true,
          float = {
            focusable = false,
            style = "minimal",
            border = "rounded",
            source = true,
            header = "",
            prefix = "",
          },
        })

        require("lsp-file-operations").setup()

        vim.lsp.codelens.enable(true)
      '';
    };
  };
}
