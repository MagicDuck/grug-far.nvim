local utils = require('grug-far.utils')

--- aborts all currently running tasks
---@param params { buf: integer, context: GrugFarContext }
local function abort(params)
  local context = params.context

  local abortedAny = utils.abortTasks(context)

  -- clear stuff
  if abortedAny then
    vim.notify('grug-far: task aborted!', vim.log.levels.INFO)
  end
end

return abort
