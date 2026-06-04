-- Formatting via conform.nvim (replaces none-ls formatting).
-- Format-on-save with LSP fallback so filetypes without a dedicated
-- formatter (e.g. nix via nixd) still get formatted.
return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "v" },
      desc = "Format buffer/selection",
    },
    {
      "<leader>uf",
      function()
        vim.g.disable_autoformat = not vim.g.disable_autoformat
        vim.notify("Autoformat " .. (vim.g.disable_autoformat and "disabled" or "enabled"), vim.log.levels.INFO)
      end,
      desc = "Toggle autoformat-on-save",
    },
  },
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      go = { "gofmt", "goimports_reviser" },
      python = { "isort", "black" },
      rust = { "rustfmt" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      markdown = { "prettier" },
      ["markdown.mdx"] = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      yaml = { "prettier" },
      sql = { "sqlfluff" },
      proto = { "buf" },
    },
    format_on_save = function(bufnr)
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return
      end
      return { timeout_ms = 3000, lsp_format = "fallback" }
    end,
    formatters = {
      shfmt = {
        prepend_args = { "-i", "2", "-ci" },
      },
      goimports_reviser = {
        prepend_args = { "-company-prefixes", "git.divar.cloud/divar" },
      },
      sqlfluff = {
        args = function()
          local args = { "format", "--dialect", "postgres" }
          if vim.fn.filereadable(vim.fn.getcwd() .. "/.sqlfluff") == 1 then
            vim.list_extend(args, { "--config", "$ROOT/.sqlfluff" })
          end
          vim.list_extend(args, { "-" })
          return args
        end,
      },
    },
  },
}
