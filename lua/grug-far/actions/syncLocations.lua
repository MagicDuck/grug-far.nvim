local sync = require('grug-far.actions.sync')
local history = require('grug-far.history')

--- syncs all result lines with original file locations
---@param params { buf: integer, context: grug.far.Context }
local function syncLocations(params)
  local buf = params.buf
  local context = params.context

  sync({
    buf = buf,
    context = context,
    startRow = 0,
    endRow = -1,
    on_success = function()
      local autoSave = context.options.history.autoSave
      if autoSave.enabled and autoSave.onSyncAll then
        history.addHistoryEntry(context, buf)
      end
    end,
  })
end

return syncLocations
