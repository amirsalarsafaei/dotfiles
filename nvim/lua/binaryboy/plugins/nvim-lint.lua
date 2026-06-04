-- Linting via nvim-lint (replaces none-ls diagnostics).
-- Linters only run when their executable is available.
return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local lint = require("lint")

    lint.linters_by_ft = {
      yaml = { "yamllint" },
      dockerfile = { "hadolint" },
    }

    local function try_lint()
      local names = lint.linters_by_ft[vim.bo.filetype] or {}
      local runnable = {}
      for _, name in ipairs(names) do
        local linter = lint.linters[name]
        local cmd = type(linter) == "table" and linter.cmd or name
        if vim.fn.executable(cmd) == 1 then
          table.insert(runnable, name)
        end
      end
      if #runnable > 0 then
        lint.try_lint(runnable)
      end
    end

    local group = vim.api.nvim_create_augroup("NvimLint", { clear = true })
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
      group = group,
      callback = try_lint,
    })
  end,
}
