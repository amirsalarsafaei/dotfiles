local M = {
  ai = false,
  wakatime = false,
  mason = true,
  palette = {},
}

local xdg_config = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")
local config_path = xdg_config .. "/nvim-host.lua"

if vim.fn.filereadable(config_path) == 1 then
  local ok, host = pcall(dofile, config_path)
  if ok and type(host) == "table" then
    M = vim.tbl_deep_extend("force", M, host)
  end
end

return M
