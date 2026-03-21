local hostconfig = require("binaryboy.core.hostconfig")

return {
  "yetone/avante.nvim",
  enabled = hostconfig.ai,
  event = "VeryLazy",
  lazy = false,
  version = false, -- set this if you want to always pull the latest change
  build = "make BUILD_FROM_SOURCE=false",
  -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    --- The below dependencies are optional,
    ---
    "echasnovski/mini.pick",         -- for file_selector provider mini.pick
    "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
    "hrsh7th/nvim-cmp",              -- autocompletion for avante commands and mentions
    "ibhagwan/fzf-lua",              -- for file_selector provider fzf
    "nvim-tree/nvim-web-devicons",   -- or echasnovski/mini.icons
    "zbirenbaum/copilot.lua",        -- for providers='copilot'
    {
      -- support for image pasting
      "HakonHarnes/img-clip.nvim",
      event = "VeryLazy",
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          -- use_absolute_path = true,
        },
      },
    },
    {
      -- Make sure to set this up properly if you have lazy=true
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        file_types = { "markdown", "Avante" },
      },
      ft = { "markdown", "Avante" },
    },
  },

  opts = {
    provider = "claude",
    providers = {
      claude = {
        endpoint = "https://litellm.data.divar.cloud",
      },
      openai = {
        endpoint = "https://litellm.data.divar.cloud",
      },
      ollama = {
        __inherited_from = "openai",
        api_key_name = "",
        endpoint = "http://127.0.0.1:11434/v1",
        model = "qwen3-coder:30b",
        timeout = 40000,
        disable_tools = false,
        extra_request_body = {
          temperature = 0.2,
          top_k = 40,
          top_p = 0.9,
          max_tokens = 8192,
        },
      },
    },
    mode = "agentic",
    disabled_tools = { "web_search" },
  },
}
