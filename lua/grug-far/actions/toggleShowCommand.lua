local search = require('grug-far.actions.search')

--- toggles displaying search command
---@param params { buf: integer, context: grug.far.Context }
local function toggleShowCommand(params)
  local context = params.context
  local buf = params.buf

  context.state.showSearchCommand = not context.state.showSearchCommand

  vim.notify(
    'grug-far: show command toggled ' .. (context.state.showSearchCommand and 'on' or 'off') .. '!',
    vim.log.levels.INFO
  )
  search({ buf = buf, context = context })
end

return toggleShowCommand
