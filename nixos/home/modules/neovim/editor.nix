{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.custom.neovim;
  helpers = import ./lib.nix { inherit lib config; };
  inherit (helpers) normalKeymap;
in
{
  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      extraPlugins = with pkgs.vimPlugins; [
        telescope-ui-select-nvim
        vim-helm
      ];

      keymaps = [
        (normalKeymap "<leader>ee" "<cmd>NvimTreeToggle<CR>" { desc = "Toggle file explorer"; })
        (normalKeymap "<leader>ef" "<cmd>NvimTreeFindFileToggle<CR>" { desc = "Find file in explorer"; })
        (normalKeymap "<leader>ec" "<cmd>NvimTreeCollapse<CR>" { desc = "Collapse explorer"; })
        (normalKeymap "<leader>er" "<cmd>NvimTreeRefresh<CR>" { desc = "Refresh explorer"; })
        (normalKeymap "<leader>xx" "<cmd>Trouble diagnostics toggle<CR>" { desc = "Diagnostics"; })
        (normalKeymap "<leader>xX" "<cmd>Trouble diagnostics toggle filter.buf=0<CR>" { desc = "Buffer diagnostics"; })
        (normalKeymap "<leader>xs" "<cmd>Trouble symbols toggle focus=false<CR>" { desc = "Symbols"; })
        (normalKeymap "<leader>xl" "<cmd>Trouble lsp toggle focus=false win.position=right<CR>" { desc = "LSP definitions"; })
        (normalKeymap "<leader>xL" "<cmd>Trouble loclist toggle<CR>" { desc = "Location list"; })
        (normalKeymap "<leader>xq" "<cmd>Trouble qflist toggle<CR>" { desc = "Quickfix list"; })
        (normalKeymap "<leader>xt" "<cmd>Trouble todo toggle<CR>" { desc = "TODOs (Trouble)"; })
        (normalKeymap "<leader>ft" "<cmd>TodoTelescope<CR>" { desc = "Find TODOs"; })
      ];

      plugins = {
        web-devicons.enable = true;

        mini = {
          enable = true;
          modules = {
            base16 = { };
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
              { __unkeyed-1 = "<leader>b"; group = "buffer"; }
              { __unkeyed-1 = "<leader>c"; group = "code"; }
              { __unkeyed-1 = "<leader>e"; group = "explorer"; }
              { __unkeyed-1 = "<leader>f"; group = "find/file"; }
              { __unkeyed-1 = "<leader>g"; group = "git"; }
              { __unkeyed-1 = "<leader>h"; group = "git hunks"; }
              { __unkeyed-1 = "<leader>p"; group = "platformio"; mode = "n"; }
              { __unkeyed-1 = "<leader>q"; group = "session"; }
              { __unkeyed-1 = "<leader>r"; group = "run/debug"; }
              { __unkeyed-1 = "<leader>R"; group = "search/replace"; }
              { __unkeyed-1 = "<leader>s"; group = "split"; }
              { __unkeyed-1 = "<leader>t"; group = "terminal/tabs"; }
              { __unkeyed-1 = "<leader>u"; group = "ui/toggle"; }
              { __unkeyed-1 = "<leader>x"; group = "trouble"; }
              { __unkeyed-1 = "<leader><leader>"; group = "swap window"; }
              { __unkeyed-1 = "["; group = "prev"; }
              { __unkeyed-1 = "]"; group = "next"; }
              { __unkeyed-1 = "g"; group = "goto"; }
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
                horizontal = {
                  prompt_position = "top";
                  preview_width = 0.55;
                };
                width = 0.87;
                height = 0.80;
              };
              path_display = [ "truncate" ];
              preview.treesitter = false;
              mappings = {
                i = {
                  "<C-k>".__raw = ''require("telescope.actions").move_selection_previous'';
                  "<C-j>".__raw = ''require("telescope.actions").move_selection_next'';
                  "<C-u>".__raw = ''require("telescope.actions").preview_scrolling_up'';
                  "<C-d>".__raw = ''require("telescope.actions").preview_scrolling_down'';
                  "<C-q>".__raw = ''require("telescope.actions").send_to_qflist + require("telescope.actions").open_qflist'';
                  "<Esc>".__raw = ''require("telescope.actions").close'';
                };
                n = {
                  "q".__raw = ''require("telescope.actions").close'';
                };
              };
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
                mappings = {
                  i."<C-x>".__raw = ''require("telescope.actions").delete_buffer'';
                  n."dd".__raw = ''require("telescope.actions").delete_buffer'';
                };
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
              icons = {
                show = {
                  git = true;
                  folder = true;
                  file = true;
                  folder_arrow = true;
                };
                glyphs = {
                  default = "󰈚";
                  symlink = "";
                  folder = {
                    default = "";
                    empty = "";
                    empty_open = "";
                    open = "";
                    symlink = "";
                    symlink_open = "";
                    arrow_open = "";
                    arrow_closed = "";
                  };
                  git = {
                    unstaged = "✗";
                    staged = "✓";
                    unmerged = "";
                    renamed = "➜";
                    untracked = "★";
                    deleted = "";
                    ignored = "◌";
                  };
                };
              };
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

        flash.enable = true;
        trouble = {
          enable = true;
          settings.focus = true;
        };
        todo-comments.enable = true;
        nvim-surround.enable = true;
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
        guess-indent.enable = true;
        refactoring.enable = true;
        harpoon.enable = true;
        spectre.enable = true;
        smart-splits.enable = true;

        persistence = {
          enable = true;
          settings = { };
        };

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
      };

      extraConfigLua = ''
        require("mini.ai").setup({
          n_lines = 500,
          custom_textobjects = {
            o = require("mini.ai").gen_spec.treesitter({
              a = { "@block.outer", "@conditional.outer", "@loop.outer" },
              i = { "@block.inner", "@conditional.inner", "@loop.inner" },
            }),
            f = require("mini.ai").gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
            c = require("mini.ai").gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
            u = require("mini.ai").gen_spec.function_call(),
            U = require("mini.ai").gen_spec.function_call({ name_pattern = "[%w_]" }),
          },
        })

        -- persistence keymaps
        vim.keymap.set("n", "<leader>qs", function() require("persistence").load() end, { desc = "Restore Session", silent = true })
        vim.keymap.set("n", "<leader>qS", function() require("persistence").select() end, { desc = "Select Session", silent = true })
        vim.keymap.set("n", "<leader>ql", function() require("persistence").load({ last = true }) end, { desc = "Restore Last Session", silent = true })
        vim.keymap.set("n", "<leader>qd", function() require("persistence").stop() end, { desc = "Don't Save Session", silent = true })

        -- todo-comments navigation
        vim.keymap.set("n", "]t", function() require("todo-comments").jump_next() end, { desc = "Next TODO", silent = true })
        vim.keymap.set("n", "[t", function() require("todo-comments").jump_prev() end, { desc = "Prev TODO", silent = true })

        -- guess-indent excludes
        require("guess-indent").setup({
          filetype_exclude = {
            "c", "cpp", "objc", "objcpp", "cuda",
            "netrw", "tutor",
          },
        })

        -- harpoon
        vim.keymap.set("n", "<leader>A", function() require("harpoon"):list():add() end, { desc = "Harpoon add file", silent = true })
        vim.keymap.set("n", "<C-e>", function()
          local harpoon = require("harpoon")
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end, { desc = "Harpoon menu", silent = true })
        for i = 1, 5 do
          vim.keymap.set("n", "<C-" .. i .. ">", function()
            require("harpoon"):list():select(i)
          end, { desc = "Harpoon file " .. i, silent = true })
        end

        -- spectre
        vim.keymap.set("n", "<leader>R", function() require("spectre").toggle() end, { desc = "Toggle Spectre", silent = true })
        vim.keymap.set("n", "<leader>Rw", function() require("spectre").open_visual({ select_word = true }) end, { desc = "Search current word", silent = true })
        vim.keymap.set("v", "<leader>Rw", function() require("spectre").open_visual() end, { desc = "Search current word", silent = true })
        vim.keymap.set("n", "<leader>Rf", function() require("spectre").open_file_search({ select_word = true }) end, { desc = "Search on current file", silent = true })

        -- smart-splits
        vim.keymap.set("n", "<A-h>", function() require("smart-splits").resize_left() end, { desc = "Resize left", silent = true })
        vim.keymap.set("n", "<A-j>", function() require("smart-splits").resize_down() end, { desc = "Resize down", silent = true })
        vim.keymap.set("n", "<A-k>", function() require("smart-splits").resize_up() end, { desc = "Resize up", silent = true })
        vim.keymap.set("n", "<A-l>", function() require("smart-splits").resize_right() end, { desc = "Resize right", silent = true })
        vim.keymap.set("n", "<C-h>", function() require("smart-splits").move_cursor_left() end, { desc = "Move left", silent = true })
        vim.keymap.set("n", "<C-j>", function() require("smart-splits").move_cursor_down() end, { desc = "Move down", silent = true })
        vim.keymap.set("n", "<C-k>", function() require("smart-splits").move_cursor_up() end, { desc = "Move up", silent = true })
        vim.keymap.set("n", "<C-l>", function() require("smart-splits").move_cursor_right() end, { desc = "Move right", silent = true })
        vim.keymap.set("n", "<leader><leader>h", function() require("smart-splits").swap_buf_left() end, { desc = "Swap left", silent = true })
        vim.keymap.set("n", "<leader><leader>j", function() require("smart-splits").swap_buf_down() end, { desc = "Swap down", silent = true })
        vim.keymap.set("n", "<leader><leader>k", function() require("smart-splits").swap_buf_up() end, { desc = "Swap up", silent = true })
        vim.keymap.set("n", "<leader><leader>l", function() require("smart-splits").swap_buf_right() end, { desc = "Swap right", silent = true })

        -- flash
        vim.keymap.set({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash", silent = true })
        vim.keymap.set({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter", silent = true })
        vim.keymap.set("o", "r", function() require("flash").remote() end, { desc = "Remote Flash", silent = true })
        vim.keymap.set({ "o", "x" }, "R", function() require("flash").treesitter_search() end, { desc = "Treesitter Search", silent = true })
        vim.keymap.set("c", "<c-s>", function() require("flash").toggle() end, { desc = "Toggle Flash Search", silent = true })

        -- mini.bufremove
        vim.keymap.set("n", "<leader>bd", function() require("mini.bufremove").delete(0, false) end, { desc = "Delete buffer", silent = true })
        vim.keymap.set("n", "<leader>bD", function() require("mini.bufremove").delete(0, true) end, { desc = "Delete buffer (force)", silent = true })

        -- which-key buffer-local help
        vim.keymap.set("n", "<leader>?", function() require("which-key").show({ global = false }) end, { desc = "Buffer Keymaps", silent = true })

        -- snacks keymaps + toggles
        vim.keymap.set("n", "<leader>un", function() Snacks.notifier.hide() end, { desc = "Dismiss notifications", silent = true })
        vim.keymap.set("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit", silent = true })
        vim.keymap.set("n", "<leader>gb", function() Snacks.git.blame_line() end, { desc = "Git blame line", silent = true })
        vim.keymap.set("n", "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Git browse", silent = true })
        vim.keymap.set("n", "<leader>gf", function() Snacks.lazygit.log_file() end, { desc = "Lazygit file log", silent = true })
        vim.keymap.set("n", "<leader>gl", function() Snacks.lazygit.log() end, { desc = "Lazygit log", silent = true })
        vim.keymap.set({ "n", "t" }, "]r", function() Snacks.words.jump(1, true) end, { desc = "Next reference", silent = true })
        vim.keymap.set({ "n", "t" }, "[r", function() Snacks.words.jump(-1, true) end, { desc = "Prev reference", silent = true })
        vim.keymap.set("n", "<leader>N", function()
          Snacks.win({
            file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
            width = 0.6,
            height = 0.6,
            wo = { spell = false, wrap = false, signcolumn = "yes", statuscolumn = " ", conceallevel = 3 },
          })
        end, { desc = "Neovim News", silent = true })

        vim.api.nvim_create_autocmd("User", {
          pattern = "VeryLazy",
          callback = function()
            _G.dd = function(...) Snacks.debug.inspect(...) end
            _G.bt = function() Snacks.debug.backtrace() end
            vim.print = _G.dd

            Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
            Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
            Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
            Snacks.toggle.diagnostics():map("<leader>ud")
            Snacks.toggle.line_number():map("<leader>ul")
            Snacks.toggle
              .option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
              :map("<leader>uc")
            Snacks.toggle.treesitter():map("<leader>uT")
            Snacks.toggle.inlay_hints():map("<leader>ui")
          end,
        })

        -- treesitter-textobjects
        require("nvim-treesitter-textobjects").setup({
          select = {
            lookahead = true,
            selection_modes = {
              ["@parameter.outer"] = "v",
              ["@function.outer"] = "V",
              ["@class.outer"] = "V",
            },
            include_surrounding_whitespace = false,
          },
          move = {
            set_jumps = true,
          },
        })

        local ts_select = require("nvim-treesitter-textobjects.select")
        vim.keymap.set({ "x", "o" }, "af", function() ts_select.select_textobject("@function.outer", "textobjects") end, { desc = "Select outer function" })
        vim.keymap.set({ "x", "o" }, "if", function() ts_select.select_textobject("@function.inner", "textobjects") end, { desc = "Select inner function" })
        vim.keymap.set({ "x", "o" }, "ac", function() ts_select.select_textobject("@class.outer", "textobjects") end, { desc = "Select outer class" })
        vim.keymap.set({ "x", "o" }, "ic", function() ts_select.select_textobject("@class.inner", "textobjects") end, { desc = "Select inner class" })
        vim.keymap.set({ "x", "o" }, "aa", function() ts_select.select_textobject("@parameter.outer", "textobjects") end, { desc = "Select outer argument" })
        vim.keymap.set({ "x", "o" }, "ia", function() ts_select.select_textobject("@parameter.inner", "textobjects") end, { desc = "Select inner argument" })
        vim.keymap.set({ "x", "o" }, "ai", function() ts_select.select_textobject("@conditional.outer", "textobjects") end, { desc = "Select outer conditional" })
        vim.keymap.set({ "x", "o" }, "ii", function() ts_select.select_textobject("@conditional.inner", "textobjects") end, { desc = "Select inner conditional" })
        vim.keymap.set({ "x", "o" }, "al", function() ts_select.select_textobject("@loop.outer", "textobjects") end, { desc = "Select outer loop" })
        vim.keymap.set({ "x", "o" }, "il", function() ts_select.select_textobject("@loop.inner", "textobjects") end, { desc = "Select inner loop" })

        local ts_move = require("nvim-treesitter-textobjects.move")
        vim.keymap.set({ "n", "x", "o" }, "]m", function() ts_move.goto_next_start("@function.outer", "textobjects") end, { desc = "Next function start" })
        vim.keymap.set({ "n", "x", "o" }, "]]", function() ts_move.goto_next_start("@class.outer", "textobjects") end, { desc = "Next class start" })
        vim.keymap.set({ "n", "x", "o" }, "]a", function() ts_move.goto_next_start("@parameter.inner", "textobjects") end, { desc = "Next argument" })
        vim.keymap.set({ "n", "x", "o" }, "]M", function() ts_move.goto_next_end("@function.outer", "textobjects") end, { desc = "Next function end" })
        vim.keymap.set({ "n", "x", "o" }, "][", function() ts_move.goto_next_end("@class.outer", "textobjects") end, { desc = "Next class end" })
        vim.keymap.set({ "n", "x", "o" }, "[m", function() ts_move.goto_previous_start("@function.outer", "textobjects") end, { desc = "Previous function start" })
        vim.keymap.set({ "n", "x", "o" }, "[[", function() ts_move.goto_previous_start("@class.outer", "textobjects") end, { desc = "Previous class start" })
        vim.keymap.set({ "n", "x", "o" }, "[a", function() ts_move.goto_previous_start("@parameter.inner", "textobjects") end, { desc = "Previous argument" })
        vim.keymap.set({ "n", "x", "o" }, "[M", function() ts_move.goto_previous_end("@function.outer", "textobjects") end, { desc = "Previous function end" })
        vim.keymap.set({ "n", "x", "o" }, "[]", function() ts_move.goto_previous_end("@class.outer", "textobjects") end, { desc = "Previous class end" })

        local ts_swap = require("nvim-treesitter-textobjects.swap")
        vim.keymap.set("n", "<leader>sa", function() ts_swap.swap_next("@parameter.inner") end, { desc = "Swap with next argument", silent = true })
        vim.keymap.set("n", "<leader>sA", function() ts_swap.swap_previous("@parameter.inner") end, { desc = "Swap with previous argument", silent = true })
      '';
    };
  };
}
