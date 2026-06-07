-- Polished UI for cmdline, popupmenu, and LSP markdown.
-- Notifications stay owned by snacks.notifier (noice.notify disabled) and
-- insert-mode completion stays owned by blink.cmp, so there is no overlap.
return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    notify = { enabled = false }, -- snacks.notifier owns vim.notify
    messages = { enabled = false }, -- avoid double-handling with snacks
    lsp = {
      signature = { enabled = false }, -- blink.cmp provides signature help
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true,
      },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
      lsp_doc_border = true,
    },
  },
}
