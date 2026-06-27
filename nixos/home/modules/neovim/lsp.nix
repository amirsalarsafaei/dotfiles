{ config
, lib
, ...
}:
let
  cfg = config.custom.neovim;
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      plugins = {
        lazydev.enable = true;
        fidget.enable = true;
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
                nixpkgs.expr = "import <nixpkgs> { }";
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
            ts_ls.enable = true;
            rust_analyzer = {
              enable = true;
              installCargo = false;
              installRustc = false;
            };
            cssls.enable = true;
            html.enable = true;
            dockerls.enable = true;
            docker_compose_language_service.enable = true;
            bashls.enable = true;
            elixirls.enable = true;
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
                "--compile-commands-dir=."
                "--header-insertion=iwyu"
                "--suggest-missing-includes"
              ];
              extraOptions.init_options = {
                clangdFileStatus = true;
                usePlaceholders = true;
                completeUnimported = true;
                semanticHighlighting = true;
              };
            };
            jdtls = {
              enable = true;
              cmd = [ "jdtls" ];
              filetypes = [ "java" ];
              extraOptions.root_markers = [
                "build.gradle"
                "build.gradle.kts"
                "settings.gradle"
                "settings.gradle.kts"
                "pom.xml"
                ".git"
              ];
              settings.java = {
                inlayHints.parameterNames.enabled = "all";
                signatureHelp.enabled = true;
                completion = {
                  favoriteStaticMembers = [
                    "org.junit.Assert.*"
                    "org.junit.jupiter.api.Assertions.*"
                    "org.mockito.Mockito.*"
                    "java.util.Objects.requireNonNull"
                    "java.util.Objects.requireNonNullElse"
                  ];
                  filteredTypes = [
                    "com.sun.*"
                    "io.micrometer.shaded.*"
                    "java.awt.*"
                    "jdk.*"
                    "sun.*"
                  ];
                };
                sources.organizeImports = {
                  starThreshold = 9999;
                  staticStarThreshold = 9999;
                };
                codeGeneration = {
                  toString.template = "\${object.className}{\${member.name()}=\${member.value}, \${otherMembers}}";
                  useBlocks = true;
                };
              };
            };
          };
          keymaps = {
            diagnostic = {
              "[d" = "goto_prev";
              "]d" = "goto_next";
              "<leader>cd" = "open_float";
              "<leader>cq" = "setloclist";
            };
            lspBuf = {
              gd = "definition";
              gD = "declaration";
              gr = "references";
              gi = "implementation";
              gy = "type_definition";
              K = "hover";
              gs = "signature_help";
              "<leader>cr" = "rename";
              "<leader>ca" = "code_action";
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

        vim.keymap.set("n", "<leader>uh", function()
          local bufnr = vim.api.nvim_get_current_buf()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
        end, { desc = "Toggle inlay hints", silent = true })

        vim.api.nvim_create_autocmd("LspAttach", {
          group = vim.api.nvim_create_augroup("UserLspDocumentHighlight", { clear = true }),
          callback = function(ev)
            local client = vim.lsp.get_client_by_id(ev.data.client_id)
            local bufnr = ev.buf

            if vim.api.nvim_buf_get_name(bufnr):match("^fugitive://") then
              return
            end

            if client and client:supports_method("textDocument/documentHighlight") then
              local hl_group = vim.api.nvim_create_augroup("LspHighlight_" .. bufnr, { clear = true })

              vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                buffer = bufnr,
                group = hl_group,
                callback = vim.lsp.buf.document_highlight,
              })

              vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                buffer = bufnr,
                group = hl_group,
                callback = vim.lsp.buf.clear_references,
              })
            end
          end,
        })
      '';
    };
  };
}
