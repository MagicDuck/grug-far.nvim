local sync = require('grug-far/actions/sync')

local function syncLocations(params)
  sync({
    buf = params.buf,
    context = params.context,
    startRow = 0,
    endRow = -1
  })
end

return syncLocations
