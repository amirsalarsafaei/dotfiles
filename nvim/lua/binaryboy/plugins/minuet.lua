local hostconfig = require("binaryboy.core.hostconfig")

return {
  "milanglacier/minuet-ai.nvim",
  enabled = hostconfig.ai,
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("minuet").setup({
      provider = "openai_compatible",
      request_timeout = 30,
      throttle = 100,
      debounce = 100,
      context_window = 1024,
      after_cursor_filter_length = 10,
      add_single_line_entry = true,
      n_completions = 2,
      blink = {
        enable_auto_complete = true,
      },
      provider_options = {
        openai_compatible = {
          api_key = function() return "ollama" end,
          end_point = "http://127.0.0.1:11434/v1/chat/completions",
          model = "danielsheep/Qwen3-Coder-30B-A3B-Instruct-1M-Unsloth:UD-IQ3_XXS",
          name = "Ollama",
          optional = {
            max_tokens = 200,
            temperature = 0.3,
            top_p = 0.9,
            top_k = 40,
          },
        },
      },
      virtualtext = {
        auto_trigger_ft = { "python", "lua", "go", "rust", "typescript", "javascript", "c", "cpp", "java", "bash", "sh", "json", "yaml", "vim" },
        auto_trigger_ignore_ft = { "markdown", "help", "text", "toggleterm" },
        show_on_completion_menu = false,
        keymap = {
          accept = "<A-a>",
          accept_line = "<A-l>",
          accept_n_lines = "<A-z>",
          prev = "<A-[>",
          next = "<A-]>",
          dismiss = "<A-e>",
        },
      },
    })

    -- AI provider state tracking
    local ai_state = {
      current = "copilot",
    }

    vim.schedule(function()
      local map = vim.keymap.set

      map("n", "<leader>mo", function()
        local blink = require("blink.cmp")
        if not (blink.config and blink.config.sources and blink.config.sources.default) then
          return
        end

        local sources = blink.config.sources.default
        if ai_state.current == "copilot" then
          for i, v in ipairs(sources) do
            if v == "copilot" then
              sources[i] = "minuet"
              ai_state.current = "ollama"
              vim.notify("AI: Ollama", vim.log.levels.INFO)
              break
            end
          end
        else
          for i, v in ipairs(sources) do
            if v == "minuet" then
              sources[i] = "copilot"
              ai_state.current = "copilot"
              vim.notify("AI: Copilot", vim.log.levels.INFO)
              break
            end
          end
        end
      end, { desc = "Toggle AI provider" })

      map("n", "<leader>ms", function()
        vim.notify("AI: " .. (ai_state.current == "copilot" and "Copilot" or "Ollama"), vim.log.levels.INFO)
      end, { desc = "Show AI provider" })
    end)
  end,
}
