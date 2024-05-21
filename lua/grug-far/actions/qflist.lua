local utils = require('grug-far/utils')

local function qflist(params)
  local context = params.context
  local state = context.state
  local resultsLocations = state.resultsLocations

  if #resultsLocations == 0 then
    return
  end

  local search = state.inputs.search

  vim.fn.setqflist(resultsLocations, 'r')
  vim.fn.setqflist(
    {},
    'a',
    {
      title = 'Grug FAR results'
        .. utils.strEllideAfter(search, context.options.maxSearchCharsInTitles, ' for: '),
    }
  )
  -- open list below taking whole horizontal space
  vim.cmd('botright copen | stopinsert')
end

return qflist
