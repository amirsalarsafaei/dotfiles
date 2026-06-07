return {
  {
    "anurag3301/nvim-platformio.lua",
    dependencies = {
      "akinsho/toggleterm.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = {
      "Pioinit",
      "Piorun",
      "Pioupload",
      "Piomonitor",
      "Piolog",
      "Piodebug",
    },
    keys = {
      { "<leader>pb", "<cmd>Piorun<CR>",     desc = "PlatformIO: Build" },
      { "<leader>pu", "<cmd>Pioupload<CR>",  desc = "PlatformIO: Upload" },
      { "<leader>pm", "<cmd>Piomonitor<CR>", desc = "PlatformIO: Serial Monitor" },
      { "<leader>pl", "<cmd>Piolog<CR>",     desc = "PlatformIO: Log" },
      { "<leader>pd", "<cmd>Piodebug<CR>",   desc = "PlatformIO: Debug (OpenOCD)" },
    },
    opts = {},
  },

  {
    "RaafatTurki/hex.nvim",
    cmd = { "HexToggle", "HexDump", "HexAssemble" },
    keys = {
      { "<leader>hx", "<cmd>HexToggle<CR>", desc = "Toggle hex view" },
    },
    opts = {},
  },
}
