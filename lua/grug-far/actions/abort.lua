local tasks = require('grug-far.tasks')

--- aborts all currently running tasks
---@param params { buf: integer, context: grug.far.Context }
local function abort(params)
  local context = params.context

  local abortedAny = tasks.abortAndFinishAllTasks(context)

  -- clear stuff
  if abortedAny then
    vim.notify('grug-far: task aborted!', vim.log.levels.INFO)
  end
end

return abort
