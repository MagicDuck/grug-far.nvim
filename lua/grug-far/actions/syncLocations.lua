local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')
local sync = require('grug-far/actions/sync')

local function syncLocations(params)
  local buf = params.buf
  local context = params.context

  sync({
    buf = params.buf,
    context = params.context,
    startRow = 0,
    endRow = -1
  })
end

return syncLocations
