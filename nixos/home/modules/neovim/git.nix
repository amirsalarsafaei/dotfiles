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
      ];

      extraConfigLua = ''
        vim.keymap.set("n", "]h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            require("gitsigns").nav_hunk("next")
          end
        end, { desc = "Next hunk", silent = true })

        vim.keymap.set("n", "[h", function()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            require("gitsigns").nav_hunk("prev")
          end
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

        vim.keymap.set("n", "<leader>hS", function()
          require("gitsigns").stage_buffer()
        end, { desc = "Stage buffer", silent = true })

        vim.keymap.set("n", "<leader>hu", function()
          require("gitsigns").undo_stage_hunk()
        end, { desc = "Undo stage hunk", silent = true })

        vim.keymap.set("n", "<leader>hR", function()
          require("gitsigns").reset_buffer()
        end, { desc = "Reset buffer", silent = true })

        vim.keymap.set("n", "<leader>hp", function()
          require("gitsigns").preview_hunk()
        end, { desc = "Preview hunk", silent = true })

        vim.keymap.set("n", "<leader>hb", function()
          require("gitsigns").blame_line({ full = true })
        end, { desc = "Blame line", silent = true })

        vim.keymap.set("n", "<leader>hB", function()
          require("gitsigns").toggle_current_line_blame()
        end, { desc = "Toggle line blame", silent = true })

        vim.keymap.set("n", "<leader>hd", function()
          require("gitsigns").diffthis()
        end, { desc = "Diff this", silent = true })

        vim.keymap.set("n", "<leader>hD", function()
          require("gitsigns").diffthis("~")
        end, { desc = "Diff this ~", silent = true })

        vim.keymap.set({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "Select hunk", silent = true })

        vim.keymap.set("n", "<leader>gD", function()
          vim.ui.input({ prompt = "Diffview — diff against ref: " }, function(ref)
            if ref and ref ~= "" then
              vim.cmd("DiffviewOpen " .. ref)
            end
          end)
        end, { desc = "Diffview: compare against ref…", silent = true })

        local function toggle_line_history(start_line, end_line)
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

        vim.keymap.set("n", "<leader>gh", function()
          local line = vim.api.nvim_win_get_cursor(0)[1]
          toggle_line_history(line, line)
        end, { desc = "Toggle git line history", silent = true })

        vim.keymap.set("x", "<leader>gh", function()
          toggle_line_history(vim.fn.line("v"), vim.fn.line("."))
        end, { desc = "Toggle git selection history", silent = true })
      '';
    };
  };
}
