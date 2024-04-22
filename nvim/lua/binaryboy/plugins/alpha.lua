return {
    "goolord/alpha-nvim",
    event = "VimEnter",
    config = function()
        local alpha = require("alpha")
        local dashboard = require("alpha.themes.dashboard")

        -- Set Header
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

          

        -- Send config to alpha
        alpha.setup(dashboard.opts)

        -- Disable folding on alpha buffer
        vim.cmd([[autocmd FileType alpha setlocal nofoldenable]])
    end
}
