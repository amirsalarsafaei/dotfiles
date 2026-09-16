{ config
, lib
, ...
}:
let
  cfg = config.custom.neovim;
  helpers = import ./lib.nix { inherit lib config; };
  inherit (helpers) mkKeymap normalKeymap;
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      plugins = {
        gitsigns = {
          enable = true;
          settings = {
            signs = {
              add.text = "▎";
              change.text = "▎";
              delete.text = "";
              topdelete.text = "";
              changedelete.text = "▎";
              untracked.text = "▎";
            };
            signs_staged_enable = true;
            current_line_blame = false;
            current_line_blame_opts = {
              virt_text = true;
              virt_text_pos = "eol";
              delay = 500;
            };
            current_line_blame_formatter = "<author>, <author_time:%R> - <summary>";
          };
        };
        fugitive.enable = true;
        diffview.enable = true;
      };

      keymaps = [
        (normalKeymap "<leader>gd" "<cmd>DiffviewOpen<CR>" { desc = "Diffview: working tree"; })
        (normalKeymap "<leader>gq" "<cmd>DiffviewClose<CR>" { desc = "Diffview: close"; })
        (normalKeymap "<leader>gr" "<cmd>DiffviewOpen origin/HEAD...HEAD<CR>" { desc = "Diffview: review branch vs origin/HEAD"; })
        (normalKeymap "<leader>gH" "<cmd>DiffviewFileHistory %<CR>" { desc = "Diffview: current file history"; })
        (normalKeymap "<leader>gA" "<cmd>DiffviewFileHistory<CR>" { desc = "Diffview: branch/repo history"; })
        (mkKeymap "v" "<leader>gl" ":GcLog<CR>" { desc = "Git log for selection"; })

        (normalKeymap "]h" {
          __raw = ''
            function()
              if vim.wo.diff then
                vim.cmd.normal({ "]c", bang = true })
              else
                require("gitsigns").nav_hunk("next")
              end
            end
          '';
        } { desc = "Next hunk"; })
        (normalKeymap "[h" {
          __raw = ''
            function()
              if vim.wo.diff then
                vim.cmd.normal({ "[c", bang = true })
              else
                require("gitsigns").nav_hunk("prev")
              end
            end
          '';
        } { desc = "Previous hunk"; })
        (normalKeymap "<leader>hs" {
          __raw = ''function() require("gitsigns").stage_hunk() end'';
        } { desc = "Stage hunk"; })
        (mkKeymap "v" "<leader>hs" {
          __raw = ''function() require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end'';
        } { desc = "Stage hunk"; })
        (normalKeymap "<leader>hr" {
          __raw = ''function() require("gitsigns").reset_hunk() end'';
        } { desc = "Reset hunk"; })
        (mkKeymap "v" "<leader>hr" {
          __raw = ''function() require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end'';
        } { desc = "Reset hunk"; })
        (normalKeymap "<leader>hS" {
          __raw = ''function() require("gitsigns").stage_buffer() end'';
        } { desc = "Stage buffer"; })
        (normalKeymap "<leader>hu" {
          __raw = ''function() require("gitsigns").undo_stage_hunk() end'';
        } { desc = "Undo stage hunk"; })
        (normalKeymap "<leader>hR" {
          __raw = ''function() require("gitsigns").reset_buffer() end'';
        } { desc = "Reset buffer"; })
        (normalKeymap "<leader>hp" {
          __raw = ''function() require("gitsigns").preview_hunk() end'';
        } { desc = "Preview hunk"; })
        (normalKeymap "<leader>hb" {
          __raw = ''function() require("gitsigns").blame_line({ full = true }) end'';
        } { desc = "Blame line"; })
        (normalKeymap "<leader>hB" {
          __raw = ''function() require("gitsigns").toggle_current_line_blame() end'';
        } { desc = "Toggle line blame"; })
        (normalKeymap "<leader>hd" {
          __raw = ''function() require("gitsigns").diffthis() end'';
        } { desc = "Diff this"; })
        (normalKeymap "<leader>hD" {
          __raw = ''function() require("gitsigns").diffthis("~") end'';
        } { desc = "Diff this ~"; })
        (mkKeymap [ "o" "x" ] "ih" ":<C-U>Gitsigns select_hunk<CR>" { desc = "Select hunk"; })

        (normalKeymap "<leader>gD" {
          __raw = ''
            function()
              vim.ui.input({ prompt = "Diffview — diff against ref: " }, function(ref)
                if ref and ref ~= "" then
                  vim.cmd("DiffviewOpen " .. ref)
                end
              end)
            end
          '';
        } { desc = "Diffview: compare against ref"; })
        (normalKeymap "<leader>gh" {
          __raw = ''
            function()
              local line = vim.api.nvim_win_get_cursor(0)[1]
              _G.diffview_line_history(line, line)
            end
          '';
        } { desc = "Toggle git line history"; })
        (mkKeymap "x" "<leader>gh" {
          __raw = ''function() _G.diffview_line_history(vim.fn.line("v"), vim.fn.line(".")) end'';
        } { desc = "Toggle git selection history"; })
      ];

      extraConfigLua = ''
        _G.diffview_line_history = function(start_line, end_line)
          local view = require("diffview.lib").get_current_view()
          if view then
            vim.cmd.DiffviewClose()
            return
          end

          if start_line > end_line then
            start_line, end_line = end_line, start_line
          end

          vim.cmd(("%d,%dDiffviewFileHistory %%"):format(start_line, end_line))
        end
      '';
    };
  };
}
