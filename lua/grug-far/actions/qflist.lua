local utils = require('grug-far/utils')

--- opens all locations in the results area in a quickfix list
---@param params { context: GrugFarContext }
local function qflist(params)
  local context = params.context
  local state = context.state
  -- TODO: should this respect deletions in the results area?
  local resultsLocations = state.resultsLocations

  if #resultsLocations == 0 then
    return
  end

  local search = state.inputs.search

  vim.fn.setqflist(resultsLocations, 'r')
  vim.fn.setqflist({}, 'a', {
    title = 'Grug FAR results'
      .. utils.strEllideAfter(search, context.options.maxSearchCharsInTitles, ' for: '),
  })
  -- open list below taking whole horizontal space
  vim.cmd('botright copen | stopinsert')
end

return qflist
