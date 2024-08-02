-- ripgrep engine API
---@type GrugFarEngine
local M = {
  type = 'ripgrep',
  search = function(str)
    return 'hi' .. str
  end,
}

return M
