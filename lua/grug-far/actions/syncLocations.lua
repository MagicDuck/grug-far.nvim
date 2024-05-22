local sync = require('grug-far/actions/sync')

--- syncs all result lines with original file locations
---@param params { buf: integer, context: GrugFarContext }
local function syncLocations(params)
  sync({
    buf = params.buf,
    context = params.context,
    startRow = 0,
    endRow = -1,
  })
end

return syncLocations
