local history = require('grug-far/history')

--- adds current UI values as history entry
---@param params { context: GrugFarContext }
local function historyAdd(params)
  local context = params.context

  history.addHistoryEntry(context.state.inputs, function(err)
    if err then
      vim.notify('grug-far: could not add to history: ' .. err, vim.log.levels.ERROR)
    else
      vim.notify('grug-far: added current search to history!', vim.log.levels.INFO)
    end
  end)
end

return historyAdd
