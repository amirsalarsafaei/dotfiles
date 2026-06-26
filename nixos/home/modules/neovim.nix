{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.custom.neovim;
  boolToLua = value: if value then "true" else "false";
  quoteLua = value: ''"${value}"'';

  themeColors =
    if config ? custom && config.custom ? theme && config.custom.theme ? resolved then
      config.custom.theme.resolved.colors
    else
      null;

  paletteKeys = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  palette = if cfg.palette != null then cfg.palette else themeColors;

  paletteLua =
    if palette == null then
      "nil"
    else
      "{\n"
      + lib.concatMapStringsSep "\n" (key: "      ${key} = ${quoteLua palette.${key}},") paletteKeys
      + "\n    }";

  mkKeymap = mode: key: action: options: {
    inherit mode key action;
    options = {
      silent = true;
    }
    // options;
  };

  normalKeymap = mkKeymap "n";
in
{
  options.custom.neovim = {
    enable = lib.mkEnableOption "Custom NixVim configuration";

    source = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Deprecated lazy.nvim config source path. Kept as a compatibility no-op while NixVim owns the generated config.";
    };

    palette = lib.mkOption {
      type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
      default = null;
      description = "Base16 color palette override for the generated NixVim config. Falls back to custom.theme.resolved.colors when available.";
    };

    features = {
      ai = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable AI features.";
      };
      wakatime = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable WakaTime time tracking.";
      };
      mason = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Deprecated. Tooling is managed by Nix instead of Mason.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables.EDITOR = "nvim";

    programs.nixvim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      nixpkgs.useGlobalPackages = true;

      globals = {
        mapleader = " ";
        maplocalleader = "\\";
        loaded_netrw = 1;
        loaded_netrwPlugin = 1;
      };

      opts = {
        relativenumber = true;
        number = true;
        tabstop = 4;
        shiftwidth = 4;
        expandtab = true;
        smartindent = true;
        wrap = false;
        ignorecase = true;
        smartcase = true;
        cursorline = true;
        termguicolors = true;
        background = "dark";
        signcolumn = "yes";
        backspace = "indent,eol,start";
        swapfile = false;
        backup = false;
        undofile = true;
        undodir.__raw = ''vim.fn.stdpath("state") .. "/undo"'';
        splitright = true;
        splitbelow = true;
        hidden = true;
        history = 500;
        synmaxcol = 240;
        updatetime = 250;
        timeoutlen = 300;
        splitkeep = "screen";
        smoothscroll = true;
        virtualedit = "block";
        completeopt = "menu,menuone,noselect";
        scrolloff = 8;
        sidescrolloff = 8;
        mouse = "a";
        clipboard = "unnamedplus";
        list = true;
        listchars = {
          tab = "» ";
          trail = "·";
          nbsp = "␣";
        };
        inccommand = "split";
        confirm = true;
        fillchars = {
          eob = " ";
        };
        shell = "zsh";
      };

      extraConfigLuaPre = ''
        vim.opt.diffopt:append({ "algorithm:histogram", "indent-heuristic", "linematch:60" })
        vim.opt.shortmess:append("sI")
        vim.opt.iskeyword:append("-")

        vim.filetype.add({
          pattern = {
            [".*/templates/.*%.ya?ml"] = "helm",
            [".*/templates/.*%.tpl"] = "helm",
            [".*/templates/.*%.txt"] = "helm",
          },
          extension = {
            tpl = "helm",
          },
        })

        local function is_helm_template(bufnr)
          local name = vim.api.nvim_buf_get_name(bufnr)
          if name:match("/templates/.*%.ya?ml$") or name:match("/templates/.*%.tpl$") then
            return true
          end

          local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, math.min(80, vim.api.nvim_buf_line_count(bufnr)), false)
          if not ok then
            return false
          end

          return table.concat(lines, "\n"):match("{{") ~= nil
        end

        _G.nvim_is_helm_template = is_helm_template

        vim.api.nvim_create_user_command("FormatDisable", function(args)
          if args.bang then
            vim.g.disable_autoformat = true
          else
            vim.b.disable_autoformat = true
          end
        end, { bang = true })

        vim.api.nvim_create_user_command("FormatEnable", function(args)
          if args.bang then
            vim.g.disable_autoformat = false
          else
            vim.b.disable_autoformat = false
          end
        end, { bang = true })

        vim.api.nvim_create_user_command("FormatToggle", function(args)
          if args.bang then
            vim.g.disable_autoformat = not vim.g.disable_autoformat
            vim.notify("Global autoformat " .. (vim.g.disable_autoformat and "disabled" or "enabled"))
          else
            vim.b.disable_autoformat = not vim.b.disable_autoformat
            vim.notify("Buffer autoformat " .. (vim.b.disable_autoformat and "disabled" or "enabled"))
          end
        end, { bang = true })

        _G.nvim_host = {
          ai = ${boolToLua cfg.features.ai},
          wakatime = ${boolToLua cfg.features.wakatime},
          mason = false,
          palette = ${paletteLua},
        }
      '';

      extraConfigLua = ''
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

        vim.keymap.set("n", "]h", function()
          require("gitsigns").nav_hunk("next")
        end, { desc = "Next hunk", silent = true })

        vim.keymap.set("n", "[h", function()
          require("gitsigns").nav_hunk("prev")
        end, { desc = "Previous hunk", silent = true })

        vim.keymap.set("n", "<leader>hs", function()
          require("gitsigns").stage_hunk()
        end, { desc = "Stage hunk", silent = true })

        vim.keymap.set("v", "<leader>hs", function()
          require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Stage hunk", silent = true })

        vim.keymap.set("n", "<leader>hr", function()
          require("gitsigns").reset_hunk()
        end, { desc = "Reset hunk", silent = true })

        vim.keymap.set("v", "<leader>hr", function()
          require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
        end, { desc = "Reset hunk", silent = true })

        vim.keymap.set("n", "<leader>hp", function()
          require("gitsigns").preview_hunk()
        end, { desc = "Preview hunk", silent = true })

        vim.keymap.set("n", "<leader>hb", function()
          require("gitsigns").blame_line({ full = true })
        end, { desc = "Blame line", silent = true })

        local palette = _G.nvim_host.palette
        if palette ~= nil then
          require("mini.base16").setup({ palette = palette })

          local hl = function(group, opts)
            vim.api.nvim_set_hl(0, group, opts)
          end

          local function apply_slate_highlights()
            hl("Normal", { fg = palette.base05, bg = palette.base00 })
            hl("NormalFloat", { fg = palette.base06, bg = palette.base01 })
            hl("FloatBorder", { fg = palette.base0D, bg = palette.base01 })
            hl("CursorLine", { bg = palette.base01 })
            hl("CursorLineNr", { fg = palette.base0A, bold = true })
            hl("LineNr", { fg = palette.base03 })
            hl("Visual", { bg = palette.base02 })
            hl("Search", { fg = palette.base00, bg = palette.base0A, bold = true })
            hl("IncSearch", { fg = palette.base00, bg = palette.base09, bold = true })
            hl("CurSearch", { fg = palette.base00, bg = palette.base09, bold = true })
            hl("MatchParen", { fg = palette.base0A, bg = palette.base02, bold = true })
            hl("Pmenu", { fg = palette.base06, bg = palette.base01 })
            hl("PmenuSel", { fg = palette.base00, bg = palette.base0D, bold = true })
            hl("PmenuThumb", { bg = palette.base0D })
            hl("WinSeparator", { fg = palette.base02 })
            hl("ColorColumn", { bg = palette.base01 })
            hl("SignColumn", { bg = palette.base00 })
            hl("DiagnosticError", { fg = palette.base08 })
            hl("DiagnosticWarn", { fg = palette.base0A })
            hl("DiagnosticInfo", { fg = palette.base0C })
            hl("DiagnosticHint", { fg = palette.base0B })
            hl("DiagnosticVirtualTextError", { fg = palette.base08, bg = palette.base01 })
            hl("DiagnosticVirtualTextWarn", { fg = palette.base0A, bg = palette.base01 })
            hl("DiagnosticVirtualTextInfo", { fg = palette.base0C, bg = palette.base01 })
            hl("DiagnosticVirtualTextHint", { fg = palette.base0B, bg = palette.base01 })
            hl("Comment", { fg = palette.base04, italic = true })
            hl("String", { fg = palette.base0B })
            hl("Character", { fg = palette.base0B })
            hl("Number", { fg = palette.base09 })
            hl("Boolean", { fg = palette.base09, bold = true })
            hl("Float", { fg = palette.base09 })
            hl("Function", { fg = palette.base0D, bold = true })
            hl("Identifier", { fg = palette.base06 })
            hl("Statement", { fg = palette.base09, bold = true })
            hl("Conditional", { fg = palette.base09, bold = true })
            hl("Repeat", { fg = palette.base09, bold = true })
            hl("Label", { fg = palette.base0A })
            hl("Operator", { fg = palette.base0C })
            hl("Keyword", { fg = palette.base09, bold = true })
            hl("Exception", { fg = palette.base08, bold = true })
            hl("PreProc", { fg = palette.base0A })
            hl("Include", { fg = palette.base0D })
            hl("Define", { fg = palette.base0A })
            hl("Macro", { fg = palette.base0A })
            hl("Type", { fg = palette.base0C, bold = true })
            hl("StorageClass", { fg = palette.base0A })
            hl("Structure", { fg = palette.base0C })
            hl("Typedef", { fg = palette.base0C })
            hl("Special", { fg = palette.base0D })
            hl("SpecialChar", { fg = palette.base0A })
            hl("Tag", { fg = palette.base0D })
            hl("Delimiter", { fg = palette.base04 })
            hl("@variable", { fg = palette.base06 })
            hl("@variable.builtin", { fg = palette.base09, bold = true })
            hl("@constant", { fg = palette.base09 })
            hl("@constant.builtin", { fg = palette.base09, bold = true })
            hl("@module", { fg = palette.base0A })
            hl("@string", { fg = palette.base0B })
            hl("@string.escape", { fg = palette.base0A })
            hl("@number", { fg = palette.base09 })
            hl("@boolean", { fg = palette.base09, bold = true })
            hl("@function", { fg = palette.base0D, bold = true })
            hl("@function.builtin", { fg = palette.base0C, bold = true })
            hl("@function.method", { fg = palette.base0D })
            hl("@constructor", { fg = palette.base0C, bold = true })
            hl("@keyword", { fg = palette.base09, bold = true })
            hl("@keyword.function", { fg = palette.base09, bold = true })
            hl("@keyword.return", { fg = palette.base08, bold = true })
            hl("@keyword.import", { fg = palette.base0D })
            hl("@operator", { fg = palette.base0C })
            hl("@type", { fg = palette.base0C, bold = true })
            hl("@type.builtin", { fg = palette.base0C, bold = true })
            hl("@property", { fg = palette.base0A })
            hl("@field", { fg = palette.base0A })
            hl("@punctuation.delimiter", { fg = palette.base04 })
            hl("@punctuation.bracket", { fg = palette.base04 })
            hl("@tag", { fg = palette.base0D })
            hl("@tag.attribute", { fg = palette.base0A })
            hl("@tag.delimiter", { fg = palette.base04 })
            hl("TelescopeNormal", { fg = palette.base06, bg = palette.base01 })
            hl("TelescopeBorder", { fg = palette.base0D, bg = palette.base01 })
            hl("TelescopeTitle", { fg = palette.base0A, bold = true })
            hl("TelescopePromptNormal", { fg = palette.base07, bg = palette.base02 })
            hl("TelescopePromptBorder", { fg = palette.base0D, bg = palette.base02 })
            hl("TelescopePromptTitle", { fg = palette.base00, bg = palette.base0D, bold = true })
            hl("TelescopePromptPrefix", { fg = palette.base0A, bg = palette.base02 })
            hl("TelescopeSelection", { fg = palette.base07, bg = palette.base02, bold = true })
            hl("TelescopeMatching", { fg = palette.base0A, bold = true })
            hl("NvimTreeNormal", { fg = palette.base06, bg = palette.base01 })
            hl("NvimTreeWinSeparator", { fg = palette.base01, bg = palette.base01 })
            hl("NvimTreeFolderName", { fg = palette.base0D })
            hl("NvimTreeOpenedFolderName", { fg = palette.base0D, bold = true })
            hl("NvimTreeRootFolder", { fg = palette.base0A, bold = true })
            hl("NvimTreeIndentMarker", { fg = palette.base03 })
            hl("NvimTreeGitDirty", { fg = palette.base0A })
            hl("NvimTreeGitNew", { fg = palette.base0B })
            hl("NvimTreeGitDeleted", { fg = palette.base08 })
            hl("NvimTreeSpecialFile", { fg = palette.base0C, bold = true })
            hl("WhichKey", { fg = palette.base0A, bold = true })
            hl("WhichKeyGroup", { fg = palette.base0C })
            hl("WhichKeyDesc", { fg = palette.base06 })
            hl("WhichKeyBorder", { fg = palette.base0D, bg = palette.base01 })
            hl("WhichKeyNormal", { bg = palette.base01 })
            hl("FlashLabel", { fg = palette.base00, bg = palette.base0A, bold = true })
            hl("FlashMatch", { fg = palette.base07, bg = palette.base02 })
            hl("FlashCurrent", { fg = palette.base00, bg = palette.base0D, bold = true })
            hl("TroubleNormal", { fg = palette.base06, bg = palette.base01 })
            hl("NotifyBackground", { bg = palette.base01 })
          end

          apply_slate_highlights()
          vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
            group = vim.api.nvim_create_augroup("SlateNixvimHighlights", { clear = true }),
            callback = apply_slate_highlights,
          })
        end
      '';

      keymaps = [
        (normalKeymap "<leader>w" "<cmd>w<CR>" { desc = "Save file"; })
        (normalKeymap "<Esc>" "<cmd>nohl<CR><Esc>" { desc = "Clear highlights on escape"; })
        (normalKeymap "j" "v:count == 0 ? 'gj' : 'j'" {
          expr = true;
          desc = "Move down wrapped";
        })
        (normalKeymap "k" "v:count == 0 ? 'gk' : 'k'" {
          expr = true;
          desc = "Move up wrapped";
        })
        (normalKeymap "<leader>sv" "<cmd>vsplit<CR>" { desc = "Split vertical"; })
        (normalKeymap "<leader>sh" "<cmd>split<CR>" { desc = "Split horizontal"; })
        (normalKeymap "<leader>se" "<C-w>=" { desc = "Equalize splits"; })
        (normalKeymap "<leader>sx" "<cmd>close<CR>" { desc = "Close split"; })
        (normalKeymap "<leader>so" "<C-w>o" { desc = "Close other splits"; })
        (normalKeymap "<C-Up>" "<cmd>resize +2<CR>" { desc = "Increase height"; })
        (normalKeymap "<C-Down>" "<cmd>resize -2<CR>" { desc = "Decrease height"; })
        (normalKeymap "<C-Left>" "<cmd>vertical resize -2<CR>" { desc = "Decrease width"; })
        (normalKeymap "<C-Right>" "<cmd>vertical resize +2<CR>" { desc = "Increase width"; })
        (normalKeymap "<leader>sr" "<C-w>r" { desc = "Rotate splits"; })
        (normalKeymap "<leader>sH" "<C-w>H" { desc = "Move split left"; })
        (normalKeymap "<leader>sJ" "<C-w>J" { desc = "Move split down"; })
        (normalKeymap "<leader>sK" "<C-w>K" { desc = "Move split up"; })
        (normalKeymap "<leader>sL" "<C-w>L" { desc = "Move split right"; })
        (normalKeymap "<leader>tn" "<cmd>tabnew<CR>" { desc = "Tab new"; })
        (normalKeymap "<leader>tc" "<cmd>tabclose<CR>" { desc = "Tab close"; })
        (normalKeymap "<leader>to" "<cmd>tabonly<CR>" { desc = "Tab only"; })
        (normalKeymap "<leader>t]" "<cmd>tabnext<CR>" { desc = "Tab next"; })
        (normalKeymap "<leader>t[" "<cmd>tabprevious<CR>" { desc = "Tab previous"; })
        (mkKeymap "v" "<" "<gv" { desc = "Indent left and reselect"; })
        (mkKeymap "v" ">" ">gv" { desc = "Indent right and reselect"; })
        (mkKeymap "v" "J" ":m '>+1<CR>gv=gv" { desc = "Move selection down"; })
        (mkKeymap "v" "K" ":m '<-2<CR>gv=gv" { desc = "Move selection up"; })
        (normalKeymap "J" "mzJ`z" { desc = "Join lines keep cursor"; })
        (normalKeymap "<C-d>" "<C-d>zz" { desc = "Page down centered"; })
        (normalKeymap "<C-u>" "<C-u>zz" { desc = "Page up centered"; })
        (normalKeymap "n" "nzzzv" { desc = "Next search centered"; })
        (normalKeymap "N" "Nzzzv" { desc = "Prev search centered"; })
        (mkKeymap "x" "<leader>p" ''"_dP'' { desc = "Paste without yanking"; })
        (mkKeymap [ "n" "v" ] "<leader>d" ''"_d'' { desc = "Delete without yanking"; })
        (normalKeymap "<leader>bn" "<cmd>bnext<CR>" { desc = "Next buffer"; })
        (normalKeymap "<leader>bp" "<cmd>bprevious<CR>" { desc = "Previous buffer"; })
        (normalKeymap "<leader>ee" "<cmd>NvimTreeToggle<CR>" { desc = "Toggle file explorer"; })
        (normalKeymap "<leader>ef" "<cmd>NvimTreeFindFileToggle<CR>" { desc = "Find file in explorer"; })
        (normalKeymap "<leader>ec" "<cmd>NvimTreeCollapse<CR>" { desc = "Collapse explorer"; })
        (normalKeymap "<leader>er" "<cmd>NvimTreeRefresh<CR>" { desc = "Refresh explorer"; })
        (normalKeymap "[q" "<cmd>cprev<CR>zz" { desc = "Previous quickfix"; })
        (normalKeymap "]q" "<cmd>cnext<CR>zz" { desc = "Next quickfix"; })
        (normalKeymap "[l" "<cmd>lprev<CR>zz" { desc = "Previous loclist"; })
        (normalKeymap "]l" "<cmd>lnext<CR>zz" { desc = "Next loclist"; })
        (normalKeymap "Q" "@q" { desc = "Replay macro q"; })
        (mkKeymap "i" "<C-c>" "<Esc>" { desc = "Exit insert mode"; })
      ];

      plugins = {
        web-devicons.enable = true;
        mini = {
          enable = true;
          modules = {
            base16 = { };
            ai.n_lines = 500;
            bufremove = { };
            icons = { };
          };
        };
        snacks = {
          enable = true;
          settings = {
            bigfile.enabled = true;
            indent.enabled = true;
            input.enabled = true;
            notifier = {
              enabled = true;
              timeout = 3000;
            };
            quickfile.enabled = true;
            scope.enabled = true;
            statuscolumn.enabled = true;
            words.enabled = true;
          };
        };
        which-key = {
          enable = true;
          settings = {
            delay = 300;
            icons = {
              mappings = true;
              keys = { };
            };
            spec = [
              {
                __unkeyed-1 = "<leader>b";
                group = "buffer";
              }
              {
                __unkeyed-1 = "<leader>c";
                group = "code";
              }
              {
                __unkeyed-1 = "<leader>e";
                group = "explorer";
              }
              {
                __unkeyed-1 = "<leader>f";
                group = "find/file";
              }
              {
                __unkeyed-1 = "<leader>g";
                group = "git";
              }
              {
                __unkeyed-1 = "<leader>h";
                group = "hunk";
              }
              {
                __unkeyed-1 = "<leader>s";
                group = "split";
              }
              {
                __unkeyed-1 = "<leader>t";
                group = "terminal/tabs";
              }
              {
                __unkeyed-1 = "<leader>u";
                group = "ui/toggle";
              }
              {
                __unkeyed-1 = "<leader>x";
                group = "trouble";
              }
            ];
          };
        };
        telescope = {
          enable = true;
          extensions = {
            fzf-native.enable = true;
            ui-select.enable = true;
          };
          settings = {
            defaults = {
              prompt_prefix = "   ";
              selection_caret = "  ";
              entry_prefix = "  ";
              sorting_strategy = "ascending";
              layout_config = {
                horizontal.prompt_position = "top";
                width = 0.87;
                height = 0.80;
              };
              path_display = [ "truncate" ];
              preview.treesitter = false;
            };
            pickers = {
              find_files.find_command = [
                "rg"
                "--files"
                "--hidden"
                "--glob"
                "!**/.git/*"
              ];
              buffers = {
                ignore_current_buffer = true;
                sort_mru = true;
              };
            };
          };
          keymaps = {
            "<leader>ff" = "find_files";
            "<leader>fg" = "live_grep";
            "<leader>fw" = "grep_string";
            "<leader>fb" = "buffers";
            "<leader>fr" = "oldfiles";
            "<leader>fh" = "help_tags";
            "<leader>fc" = "commands";
            "<leader>fk" = "keymaps";
            "<leader>fd" = "diagnostics";
            "<leader>fs" = "lsp_document_symbols";
            "<leader>fS" = "lsp_dynamic_workspace_symbols";
            "<leader>f." = "resume";
            "<leader>f/" = "current_buffer_fuzzy_find";
            "<leader>gc" = "git_commits";
            "<leader>gs" = "git_status";
          };
        };
        nvim-tree = {
          enable = true;
          openOnSetup = false;
          settings = {
            hijack_directories.enable = false;
            hijack_netrw = false;
            view = {
              width = 35;
              relativenumber = true;
            };
            filters = {
              dotfiles = false;
              git_ignored = false;
              custom = [
                "^.git$"
                "^node_modules$"
                "^__pycache__$"
                "^\\.DS_Store$"
              ];
            };
            git = {
              enable = true;
              show_on_dirs = true;
            };
            diagnostics = {
              enable = true;
              show_on_dirs = true;
              show_on_open_dirs = true;
            };
            modified = {
              enable = true;
              show_on_dirs = true;
            };
            renderer = {
              group_empty = true;
              highlight_git = true;
              highlight_opened_files = "name";
              highlight_modified = "name";
              indent_markers.enable = true;
            };
            actions.open_file = {
              quit_on_open = false;
              window_picker.enable = true;
            };
            update_focused_file = {
              enable = true;
              update_root = false;
            };
          };
        };
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
        gitsigns.enable = true;
        fugitive.enable = true;
        diffview.enable = true;
        flash.enable = true;
        trouble = {
          enable = true;
          settings.focus = true;
        };
        todo-comments.enable = true;
        nvim-autopairs = {
          enable = true;
          settings = {
            check_ts = true;
            ts_config = {
              lua = [ "string" ];
              javascript = [ "template_string" ];
              java = false;
            };
            fast_wrap = {
              map = "<M-e>";
              chars = [
                "{"
                "["
                "("
                ''"''
                "'"
              ];
              end_key = "$";
              before_key = "h";
              after_key = "l";
              cursor_pos_before = true;
              keys = "qwertyuiopzxcvbnmasdfghjkl";
              manual_position = true;
              highlight = "Search";
              highlight_grey = "Comment";
            };
          };
        };
        nvim-surround.enable = true;
        guess-indent.enable = true;
        persistence.enable = true;
        refactoring.enable = true;
        treesitter = {
          enable = true;
          nixvimInjections = false;
          settings = {
            highlight.enable = true;
            indent.enable = true;
          };
        };
        treesitter-textobjects.enable = true;
        ts-autotag.enable = true;
        blink-cmp = {
          enable = true;
          settings = {
            keymap = {
              preset = "default";
              "<C-s>" = [
                "show"
                "fallback"
              ];
              "<C-k>" = [
                "scroll_documentation_up"
                "fallback"
              ];
              "<C-j>" = [
                "scroll_documentation_down"
                "fallback"
              ];
              "<C-e>" = [
                "cancel"
                "fallback"
              ];
              "<Tab>" = [
                "accept"
                "fallback"
              ];
            };
            appearance = {
              use_nvim_cmp_as_default = true;
              nerd_font_variant = "mono";
            };
            sources = {
              default = [
                "lsp"
                "path"
                "buffer"
                "snippets"
              ];
              per_filetype.toggleterm = [
                "buffer"
                "path"
              ];
            };
            completion = {
              list.selection = {
                preselect = true;
                auto_insert = true;
              };
              accept.auto_brackets.enabled = true;
              menu.border = "rounded";
              documentation = {
                auto_show = true;
                auto_show_delay_ms = 200;
                window.border = "rounded";
              };
            };
            signature = {
              enabled = true;
              window.border = "rounded";
            };
          };
        };
        friendly-snippets.enable = true;
        lazydev.enable = true;
        fidget.enable = true;
        lsp = {
          enable = true;
          inlayHints = true;
          servers = {
            lua_ls.enable = true;
            gopls.enable = true;
            golangci_lint_ls.enable = true;
            nixd.enable = true;
            pyright.enable = true;
            yamlls.enable = true;
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
            clangd.enable = true;
            jdtls.enable = true;
          };
          keymaps = {
            diagnostic = {
              "[d" = "goto_prev";
              "]d" = "goto_next";
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
        wakatime.enable = cfg.features.wakatime;
      };

      extraPlugins = with pkgs.vimPlugins; [
        telescope-ui-select-nvim
        vim-helm
      ];

      extraPackages = with pkgs; [
        ripgrep
        fd
      ];
    };
  };
}
