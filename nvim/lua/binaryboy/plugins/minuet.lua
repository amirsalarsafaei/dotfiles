return {
  "milanglacier/minuet-ai.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("minuet").setup({
      provider = "openai_compatible",
      blink = {
        enable_auto_complete = true,
      },
      provider_options = {
        openai_compatible = {
          api_key = "NONE",
          end_point = "http://127.0.0.1:11434/v1/chat/completions",
          model = "danielsheep/Qwen3-Coder-30B-A3B-Instruct-1M-Unsloth:UD-IQ3_XXS",
          name = "Ollama",
          optional = {
            max_tokens = 256,
            top_p = 0.9,
          },
        },
      },
      virtualtext = {
        auto_trigger_ft = {},
        keymap = {
          accept = "<A-a>",
          accept_line = "<A-l>",
          prev = "<A-[>",
          next = "<A-]>",
          dismiss = "<A-e>",
        },
      },
    })

    -- Toggle minuet virtual text on/off
    vim.keymap.set("n", "<leader>me", function()
      vim.cmd("Minuet virtualtext toggle")
    end, { desc = "Toggle Minuet virtualtext" })

    -- Toggle minuet blink source on/off
    vim.keymap.set("n", "<leader>mb", function()
      vim.cmd("Minuet blink toggle")
    end, { desc = "Toggle Minuet in blink" })

    -- Switch to local (Ollama)
    vim.keymap.set("n", "<leader>ml", function()
      require("minuet").change_provider("openai_compatible")
      vim.notify("Minuet: Switched to Local (Ollama)", vim.log.levels.INFO)
    end, { desc = "Minuet: Local provider" })

    -- Show current provider
    vim.keymap.set("n", "<leader>ms", function()
      local provider = require("minuet.config").config.provider
      vim.notify("Minuet provider: " .. provider, vim.log.levels.INFO)
    end, { desc = "Minuet: Show provider" })

    -- Toggle blink.cmp source between minuet (Ollama) and copilot
    vim.keymap.set("n", "<leader>mo", function()
      local blink = require("blink.cmp")
      local sources = blink.config.sources.default
      local has_minuet = vim.tbl_contains(sources, "minuet")
      local has_copilot = vim.tbl_contains(sources, "copilot")

      if has_minuet and not has_copilot then
        for i, v in ipairs(sources) do
          if v == "minuet" then sources[i] = "copilot" break end
        end
        vim.notify("Switched to Copilot", vim.log.levels.INFO)
      else
        for i, v in ipairs(sources) do
          if v == "copilot" then sources[i] = "minuet" break end
        end
        vim.notify("Switched to Ollama (minuet)", vim.log.levels.INFO)
      end
    end, { desc = "Toggle Ollama/Copilot source" })
  end,
}
