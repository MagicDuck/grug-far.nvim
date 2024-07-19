local search = require('grug-far/actions/search')

--- toggles displaying rg command
---@param params { buf: integer, context: GrugFarContext }
local function toggleShowRgCommand(params)
  local context = params.context
  local buf = params.buf

  context.state.showRgCommand = not context.state.showRgCommand

  vim.notify(
    'grug-far: show rg command toggled ' .. (context.state.showRgCommand and 'on' or 'off') .. '!',
    vim.log.levels.INFO
  )
  search({ buf = buf, context = context })
end

return toggleShowRgCommand
