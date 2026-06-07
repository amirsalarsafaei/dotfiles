local hostconfig = require("binaryboy.core.hostconfig")

return {
  "wakatime/vim-wakatime",
  enabled = hostconfig.wakatime,
  lazy = false,
  config = function()
    -- Only enable wakatime if API key is set
    if vim.fn.empty(os.getenv("WAKATIME_HOME") or "") == 0 or
        vim.fn.filereadable(vim.fn.expand("~/.wakatime.cfg")) == 1 then
      vim.g.wakatime_PythonBinary = vim.fn.exepath("python3") or vim.fn.exepath("python")
    else
      -- Disable if no API key configured
      vim.g.wakatime_disable = 1
    end
  end,
}
