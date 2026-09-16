{ config
, lib
, pkgs
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

        (normalKeymap "<leader>qs" { __raw = ''function() require("persistence").load() end''; } {
          desc = "Restore Session";
        })
        (normalKeymap "<leader>qS" { __raw = ''function() require("persistence").select() end''; } {
          desc = "Select Session";
        })
        (normalKeymap "<leader>ql" {
          __raw = ''function() require("persistence").load({ last = true }) end'';
        } { desc = "Restore Last Session"; })
        (normalKeymap "<leader>qd" { __raw = ''function() require("persistence").stop() end''; } {
          desc = "Don't Save Session";
        })

        (normalKeymap "]t" {
          __raw = ''function() require("todo-comments").jump_next() end'';
        } { desc = "Next TODO"; })
        (normalKeymap "[t" {
          __raw = ''function() require("todo-comments").jump_prev() end'';
        } { desc = "Prev TODO"; })

        (normalKeymap "<leader>A" {
          __raw = ''function() require("harpoon"):list():add() end'';
        } { desc = "Harpoon add file"; })
        (normalKeymap "<C-e>" {
          __raw = ''
            function()
              local harpoon = require("harpoon")
              harpoon.ui:toggle_quick_menu(harpoon:list())
            end
          '';
        } { desc = "Harpoon menu"; })
      ]
      ++ map (i: normalKeymap "<C-${toString i}" {
        __raw = ''function() require("harpoon"):list():select(${toString i}) end'';
      } { desc = "Harpoon file ${toString i}"; }) (lib.range 1 5)
      ++ [
        (normalKeymap "<leader>R" { __raw = ''function() require("spectre").toggle() end''; } {
          desc = "Toggle Spectre";
        })
        (normalKeymap "<leader>Rw" {
          __raw = ''function() require("spectre").open_visual({ select_word = true }) end'';
        } { desc = "Search current word"; })
        (mkKeymap "v" "<leader>Rw" {
          __raw = ''function() require("spectre").open_visual() end'';
        } { desc = "Search current word"; })
        (normalKeymap "<leader>Rf" {
          __raw = ''function() require("spectre").open_file_search({ select_word = true }) end'';
        } { desc = "Search on current file"; })

        (normalKeymap "<A-h>" { __raw = ''function() require("smart-splits").resize_left() end''; } {
          desc = "Resize left";
        })
        (normalKeymap "<A-j>" { __raw = ''function() require("smart-splits").resize_down() end''; } {
          desc = "Resize down";
        })
        (normalKeymap "<A-k>" { __raw = ''function() require("smart-splits").resize_up() end''; } {
          desc = "Resize up";
        })
        (normalKeymap "<A-l>" { __raw = ''function() require("smart-splits").resize_right() end''; } {
          desc = "Resize right";
        })
        (normalKeymap "<C-h>" {
          __raw = ''function() require("smart-splits").move_cursor_left() end'';
        } { desc = "Move to the left window or pane"; })
        (normalKeymap "<C-j>" {
          __raw = ''function() require("smart-splits").move_cursor_down() end'';
        } { desc = "Move to the window or pane below"; })
        (normalKeymap "<C-k>" {
          __raw = ''function() require("smart-splits").move_cursor_up() end'';
        } { desc = "Move to the window or pane above"; })
        (normalKeymap "<C-l>" {
          __raw = ''function() require("smart-splits").move_cursor_right() end'';
        } { desc = "Move to the right window or pane"; })
        (normalKeymap "<leader><leader>h" {
          __raw = ''function() require("smart-splits").swap_buf_left() end'';
        } { desc = "Swap left"; })
        (normalKeymap "<leader><leader>j" {
          __raw = ''function() require("smart-splits").swap_buf_down() end'';
        } { desc = "Swap down"; })
        (normalKeymap "<leader><leader>k" {
          __raw = ''function() require("smart-splits").swap_buf_up() end'';
        } { desc = "Swap up"; })
        (normalKeymap "<leader><leader>l" {
          __raw = ''function() require("smart-splits").swap_buf_right() end'';
        } { desc = "Swap right"; })

        (mkKeymap [ "n" "x" "o" ] "s" { __raw = ''function() require("flash").jump() end''; } {
          desc = "Flash";
        })
        (mkKeymap [ "n" "x" "o" ] "S" {
          __raw = ''function() require("flash").treesitter() end'';
        } { desc = "Flash Treesitter"; })
        (mkKeymap "o" "r" { __raw = ''function() require("flash").remote() end''; } {
          desc = "Remote Flash";
        })
        (mkKeymap [ "o" "x" ] "R" {
          __raw = ''function() require("flash").treesitter_search() end'';
        } { desc = "Treesitter Search"; })
        (mkKeymap "c" "<c-s>" { __raw = ''function() require("flash").toggle() end''; } {
          desc = "Toggle Flash Search";
        })

        (normalKeymap "<leader>bd" {
          __raw = ''function() require("mini.bufremove").delete(0, false) end'';
        } { desc = "Delete buffer"; })
        (normalKeymap "<leader>bD" {
          __raw = ''function() require("mini.bufremove").delete(0, true) end'';
        } { desc = "Delete buffer (force)"; })

        (normalKeymap "<leader>?" {
          __raw = ''function() require("which-key").show({ global = false }) end'';
        } { desc = "Buffer keymaps"; })

        (normalKeymap "<leader>un" {
          __raw = ''function() require("snacks").notifier.hide() end'';
        } { desc = "Dismiss notifications"; })
        (normalKeymap "<leader>gg" {
          __raw = ''function() require("snacks").lazygit() end'';
        } { desc = "Lazygit"; })
        (normalKeymap "<leader>gb" {
          __raw = ''function() require("snacks").git.blame_line() end'';
        } { desc = "Git blame line"; })
        (normalKeymap "<leader>gB" {
          __raw = ''function() require("snacks").gitbrowse() end'';
        } { desc = "Git browse"; })
        (normalKeymap "<leader>gf" {
          __raw = ''function() require("snacks").lazygit.log_file() end'';
        } { desc = "Lazygit file log"; })
        (normalKeymap "<leader>gl" {
          __raw = ''function() require("snacks").lazygit.log() end'';
        } { desc = "Lazygit log"; })
        (mkKeymap [ "n" "t" ] "]r" {
          __raw = ''function() require("snacks").words.jump(1, true) end'';
        } { desc = "Next reference"; })
        (mkKeymap [ "n" "t" ] "[r" {
          __raw = ''function() require("snacks").words.jump(-1, true) end'';
        } { desc = "Prev reference"; })
        (normalKeymap "<leader>N" {
          __raw = ''
            function()
              require("snacks").win({
                file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
                width = 0.6,
                height = 0.6,
                wo = { spell = false, wrap = false, signcolumn = "yes", statuscolumn = " ", conceallevel = 3 },
              })
            end
          '';
        } { desc = "Neovim News"; })

        (normalKeymap "<leader>us" {
          __raw = ''function() require("snacks").toggle.option("spell", { name = "Spelling" }):toggle() end'';
        } { desc = "Toggle spelling"; })
        (normalKeymap "<leader>uw" {
          __raw = ''function() require("snacks").toggle.option("wrap", { name = "Wrap" }):toggle() end'';
        } { desc = "Toggle wrap"; })
        (normalKeymap "<leader>uL" {
          __raw = ''function() require("snacks").toggle.option("relativenumber", { name = "Relative Number" }):toggle() end'';
        } { desc = "Toggle relative number"; })
        (normalKeymap "<leader>ud" {
          __raw = ''function() require("snacks").toggle.diagnostics():toggle() end'';
        } { desc = "Toggle diagnostics"; })
        (normalKeymap "<leader>ul" {
          __raw = ''function() require("snacks").toggle.line_number():toggle() end'';
        } { desc = "Toggle line numbers"; })
        (normalKeymap "<leader>uc" {
          __raw = ''
            function()
              require("snacks").toggle
                .option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
                :toggle()
            end
          '';
        } { desc = "Toggle conceal level"; })
        (normalKeymap "<leader>uT" {
          __raw = ''function() require("snacks").toggle.treesitter():toggle() end'';
        } { desc = "Toggle treesitter"; })
        (normalKeymap "<leader>ui" {
          __raw = ''function() require("snacks").toggle.inlay_hints():toggle() end'';
        } { desc = "Toggle inlay hints"; })

        (mkKeymap [ "x" "o" ] "af" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.select").select_textobject("@function.outer", "textobjects") end
          '';
        } { desc = "Select outer function"; })
        (mkKeymap [ "x" "o" ] "if" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.select").select_textobject("@function.inner", "textobjects") end
          '';
        } { desc = "Select inner function"; })
        (mkKeymap [ "x" "o" ] "ac" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.select").select_textobject("@class.outer", "textobjects") end
          '';
        } { desc = "Select outer class"; })
        (mkKeymap [ "x" "o" ] "ic" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.select").select_textobject("@class.inner", "textobjects") end
          '';
        } { desc = "Select inner class"; })
        (mkKeymap [ "x" "o" ] "aa" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.select").select_textobject("@parameter.outer", "textobjects") end
          '';
        } { desc = "Select outer argument"; })
        (mkKeymap [ "x" "o" ] "ia" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.select").select_textobject("@parameter.inner", "textobjects") end
          '';
        } { desc = "Select inner argument"; })
        (mkKeymap [ "x" "o" ] "ai" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.select").select_textobject("@conditional.outer", "textobjects") end
          '';
        } { desc = "Select outer conditional"; })
        (mkKeymap [ "x" "o" ] "ii" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.select").select_textobject("@conditional.inner", "textobjects") end
          '';
        } { desc = "Select inner conditional"; })
        (mkKeymap [ "x" "o" ] "al" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.select").select_textobject("@loop.outer", "textobjects") end
          '';
        } { desc = "Select outer loop"; })
        (mkKeymap [ "x" "o" ] "il" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.select").select_textobject("@loop.inner", "textobjects") end
          '';
        } { desc = "Select inner loop"; })

        (mkKeymap [ "n" "x" "o" ] "]m" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.move").goto_next_start("@function.outer", "textobjects") end
          '';
        } { desc = "Next function start"; })
        (mkKeymap [ "n" "x" "o" ] "]]" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.move").goto_next_start("@class.outer", "textobjects") end
          '';
        } { desc = "Next class start"; })
        (mkKeymap [ "n" "x" "o" ] "]a" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.move").goto_next_start("@parameter.inner", "textobjects") end
          '';
        } { desc = "Next argument"; })
        (mkKeymap [ "n" "x" "o" ] "]M" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.move").goto_next_end("@function.outer", "textobjects") end
          '';
        } { desc = "Next function end"; })
        (mkKeymap [ "n" "x" "o" ] "][" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.move").goto_next_end("@class.outer", "textobjects") end
          '';
        } { desc = "Next class end"; })
        (mkKeymap [ "n" "x" "o" ] "[m" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.move").goto_previous_start("@function.outer", "textobjects") end
          '';
        } { desc = "Previous function start"; })
        (mkKeymap [ "n" "x" "o" ] "[[" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.move").goto_previous_start("@class.outer", "textobjects") end
          '';
        } { desc = "Previous class start"; })
        (mkKeymap [ "n" "x" "o" ] "[a" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.move").goto_previous_start("@parameter.inner", "textobjects") end
          '';
        } { desc = "Previous argument"; })
        (mkKeymap [ "n" "x" "o" ] "[M" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.move").goto_previous_end("@function.outer", "textobjects") end
          '';
        } { desc = "Previous function end"; })
        (mkKeymap [ "n" "x" "o" ] "[]" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.move").goto_previous_end("@class.outer", "textobjects") end
          '';
        } { desc = "Previous class end"; })

        (normalKeymap "<leader>sa" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner") end
          '';
        } { desc = "Swap with next argument"; })
        (normalKeymap "<leader>sA" {
          __raw = ''
            function() require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner") end
          '';
        } { desc = "Swap with previous argument"; })
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
              { __unkeyed-1 = "<leader>a"; group = "AI"; }
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
        smart-splits = {
          enable = true;
          settings = {
            ignored_filetypes = [
              "nofile"
              "quickfix"
              "qf"
              "prompt"
            ];
            ignored_buftypes = [ "nofile" ];
            zellij_move_focus_or_tab = true;
          };
        };

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

        require("guess-indent").setup({
          filetype_exclude = {
            "c", "cpp", "objc", "objcpp", "cuda",
            "netrw", "tutor",
          },
        })

        vim.api.nvim_create_autocmd("User", {
          pattern = "VeryLazy",
          callback = function()
            _G.dd = function(...) Snacks.debug.inspect(...) end
            _G.bt = function() Snacks.debug.backtrace() end
            vim.print = _G.dd
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

      '';
    };
  };
}
