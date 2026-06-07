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
    -- Each ft resolves to only the formatters whose binary is present (mirrors
    -- nvim-lint.lua). Keeps format-on-save from erroring on hosts shipping a
    -- minimal toolset (e.g. the server in modules/server/vim.nix); dev hosts get
    -- the full set from Nix tooling.nix.
    formatters_by_ft = (function()
      local by_ft = {
        lua = { "stylua" },
        go = { "gofmt", "goimports_reviser" },
        python = { "ruff_organize_imports", "ruff_format" },
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
      }
      local out = {}
      for ft, names in pairs(by_ft) do
        out[ft] = function(bufnr)
          local available = {}
          for _, name in ipairs(names) do
            if require("conform").get_formatter_info(name, bufnr).available then
              table.insert(available, name)
            end
          end
          return available
        end
      end
      return out
    end)(),
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
