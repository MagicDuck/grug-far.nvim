local history = require('grug-far.history')

--- adds current UI values as history entry
---@param params { context: GrugFarContext }
local function historyAdd(params)
  local context = params.context

  history.addHistoryEntry(context, true)
end

return historyAdd
