return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  init = function()
    -- Disable built-in ftplugin mappings to avoid conflicts
    vim.g.no_plugin_maps = true
  end,
  config = function()
    local ts_textobjects = require("nvim-treesitter-textobjects")

    -- Configure textobjects
    ts_textobjects.setup({
      select = {
        lookahead = true,
        selection_modes = {
          ["@parameter.outer"] = "v", -- charwise
          ["@function.outer"] = "V", -- linewise
          ["@class.outer"] = "V", -- linewise
        },
        include_surrounding_whitespace = false,
      },
      move = {
        set_jumps = true,
      },
    })

    -- Text object selection keymaps
    local select = require("nvim-treesitter-textobjects.select")
    vim.keymap.set({ "x", "o" }, "af", function()
      select.select_textobject("@function.outer", "textobjects")
    end, { desc = "Select outer function" })
    vim.keymap.set({ "x", "o" }, "if", function()
      select.select_textobject("@function.inner", "textobjects")
    end, { desc = "Select inner function" })

    vim.keymap.set({ "x", "o" }, "ac", function()
      select.select_textobject("@class.outer", "textobjects")
    end, { desc = "Select outer class" })
    vim.keymap.set({ "x", "o" }, "ic", function()
      select.select_textobject("@class.inner", "textobjects")
    end, { desc = "Select inner class" })

    vim.keymap.set({ "x", "o" }, "aa", function()
      select.select_textobject("@parameter.outer", "textobjects")
    end, { desc = "Select outer argument" })
    vim.keymap.set({ "x", "o" }, "ia", function()
      select.select_textobject("@parameter.inner", "textobjects")
    end, { desc = "Select inner argument" })

    vim.keymap.set({ "x", "o" }, "ai", function()
      select.select_textobject("@conditional.outer", "textobjects")
    end, { desc = "Select outer conditional" })
    vim.keymap.set({ "x", "o" }, "ii", function()
      select.select_textobject("@conditional.inner", "textobjects")
    end, { desc = "Select inner conditional" })

    vim.keymap.set({ "x", "o" }, "al", function()
      select.select_textobject("@loop.outer", "textobjects")
    end, { desc = "Select outer loop" })
    vim.keymap.set({ "x", "o" }, "il", function()
      select.select_textobject("@loop.inner", "textobjects")
    end, { desc = "Select inner loop" })

    -- Movement keymaps
    local move = require("nvim-treesitter-textobjects.move")

    -- Next start
    vim.keymap.set({ "n", "x", "o" }, "]m", function()
      move.goto_next_start("@function.outer", "textobjects")
    end, { desc = "Next function start" })
    vim.keymap.set({ "n", "x", "o" }, "]]", function()
      move.goto_next_start("@class.outer", "textobjects")
    end, { desc = "Next class start" })
    vim.keymap.set({ "n", "x", "o" }, "]a", function()
      move.goto_next_start("@parameter.inner", "textobjects")
    end, { desc = "Next argument" })

    -- Next end
    vim.keymap.set({ "n", "x", "o" }, "]M", function()
      move.goto_next_end("@function.outer", "textobjects")
    end, { desc = "Next function end" })
    vim.keymap.set({ "n", "x", "o" }, "][", function()
      move.goto_next_end("@class.outer", "textobjects")
    end, { desc = "Next class end" })

    -- Previous start
    vim.keymap.set({ "n", "x", "o" }, "[m", function()
      move.goto_previous_start("@function.outer", "textobjects")
    end, { desc = "Previous function start" })
    vim.keymap.set({ "n", "x", "o" }, "[[", function()
      move.goto_previous_start("@class.outer", "textobjects")
    end, { desc = "Previous class start" })
    vim.keymap.set({ "n", "x", "o" }, "[a", function()
      move.goto_previous_start("@parameter.inner", "textobjects")
    end, { desc = "Previous argument" })

    -- Previous end
    vim.keymap.set({ "n", "x", "o" }, "[M", function()
      move.goto_previous_end("@function.outer", "textobjects")
    end, { desc = "Previous function end" })
    vim.keymap.set({ "n", "x", "o" }, "[]", function()
      move.goto_previous_end("@class.outer", "textobjects")
    end, { desc = "Previous class end" })

    -- Swap keymaps
    local swap = require("nvim-treesitter-textobjects.swap")
    vim.keymap.set("n", "<leader>sa", function()
      swap.swap_next("@parameter.inner")
    end, { desc = "Swap with next argument" })
    vim.keymap.set("n", "<leader>sA", function()
      swap.swap_previous("@parameter.inner")
    end, { desc = "Swap with previous argument" })
  end,
}
