{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.custom.neovim;
  helpers = import ./lib.nix { inherit lib config; };
  inherit (helpers) boolToLua paletteLua;
in
{
  imports = [
    ./theme.nix
    ./keymaps.nix
    ./autocmds.nix
    ./lsp.nix
    ./completion.nix
    ./git.nix
    ./editor.nix
    ./ui.nix
    ./tools.nix
  ];

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
      debug = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable nvim-dap debugging stack.";
      };
      embedded = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable embedded development plugins (PlatformIO, hex editor).";
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
        suda_smart_edit = 1;
        no_plugin_maps = true;
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
            [".*/helmfile%.ya?ml"] = "helm",
            [".*%.ya?ml%.gotmpl"] = "helm",
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

      extraPackages = with pkgs; [
        ripgrep
        fd
      ];
    };
  };
}
