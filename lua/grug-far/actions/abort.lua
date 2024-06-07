--- aborts all currently running tasks
---@param params { buf: integer, context: GrugFarContext }
local function abort(params)
  local context = params.context
  local state = context.state

  local abortedAny = false
  for _, abort_fn in pairs(state.abort) do
    if abort_fn then
      abort_fn()
      abort_fn = nil
      abortedAny = true
    end
  end

  -- clear stuff
  if abortedAny then
    vim.notify('grug-far: task aborted!', vim.log.levels.INFO)
  end
end

return abort
