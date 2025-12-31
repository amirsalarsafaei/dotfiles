return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.header.val = {
      "                ______________________                 ",
      "               < save the flying cows >                        ",
      "                ----------------------                 ",
      "                       \\   ^__^                        ",
      "                        \\  (xx)\\_______                        ",
      "                           (__)\\       )\\/\\                    ",
      "                            U  ||----w |                       ",
      "                               ||     ||                       ",
    }

    dashboard.section.buttons.val = {
      dashboard.button("f", " " .. " Find file", "<cmd>Telescope find_files<CR>"),
      dashboard.button("n", " " .. " New file", "<cmd>ene<CR>"),
      dashboard.button("r", " " .. " Recent files", "<cmd>Telescope oldfiles<CR>"),
      dashboard.button("g", " " .. " Find text", "<cmd>Telescope live_grep<CR>"),
      dashboard.button("c", " " .. " Config", "<cmd>e $MYVIMRC<CR>"),
      dashboard.button("s", " " .. " Restore Session", [[<cmd>lua require("persistence").load()<CR>]]),
      dashboard.button("l", "󰒲 " .. " Lazy", "<cmd>Lazy<CR>"),
      dashboard.button("q", " " .. " Quit", "<cmd>qa<CR>"),
    }

    for _, button in ipairs(dashboard.section.buttons.val) do
      button.opts.hl = "AlphaButtons"
      button.opts.hl_shortcut = "AlphaShortcut"
    end

    dashboard.section.header.opts.hl = "AlphaHeader"
    dashboard.section.buttons.opts.hl = "AlphaButtons"
    dashboard.section.footer.opts.hl = "AlphaFooter"

    dashboard.opts.layout[1].val = 8

    alpha.setup(dashboard.opts)

    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyVimStarted",
      once = true,
      callback = function()
        local stats = require("lazy").stats()
        local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
        dashboard.section.footer.val = "⚡ Neovim loaded " ..
        stats.loaded .. "/" .. stats.count .. " plugins in " .. ms .. "ms"
        pcall(vim.cmd.AlphaRedraw)
      end,
    })
  end,
}
