local history = require('grug-far.history')

--- adds current UI values as history entry
---@param params { buf: integer, context: grug.far.Context }
local function historyAdd(params)
  local context = params.context
  local buf = params.buf

  history.addHistoryEntry(context, buf, true)
end

return historyAdd
