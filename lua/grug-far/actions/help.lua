local utils = require('grug-far/utils')

--- shows help
---@param params { buf: integer, context: GrugFarContext }
local function help(params)
  local context = params.context

  -- TODO (sbadragan): implement this
  vim.notify('grug-far:  help!', vim.log.levels.INFO)
end

return help
