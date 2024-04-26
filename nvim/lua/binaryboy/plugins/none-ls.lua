return {
    "jay-babu/mason-null-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        "williamboman/mason.nvim",
        "nvimtools/none-ls.nvim",
    },
    config = function()
        require("mason").setup()
        require("mason-null-ls").setup({
            ensure_installed = {
                "goimports-reviser",
                "pylint",
                "eslint_d",
            },
            automatic_installation = false,
            handlers = {},
        })

        local null_ls = require("null-ls")
        null_ls.setup({
            sources = {
                null_ls.builtins.formatting.gofmt,
            },
        })
        Map("n", "<leader>gf", vim.lsp.buf.format, { desc = "formats buffer" })
    end,
}
