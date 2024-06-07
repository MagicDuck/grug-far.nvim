local renderResultsHeader = require('grug-far/render/resultsHeader')

--- aborts all currently running tasks
---@param params { buf: integer, context: GrugFarContext }
local function abort(params)
  local buf = params.buf
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

  -- TODO (sbadragan): don't know how search will react to an abort ...
  -- clear stuff
  if abortedAny then
    vim.schedule(function()
      -- vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
      -- state.status = nil
      -- state.progressCount = 0
      -- state.actionMessage = 'Aborted task!'
      -- renderResultsHeader(buf, context)
      -- vim.cmd.checktime()
      -- vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
      vim.notify('grug-far: Aborted!!!!', vim.log.levels.INFO)
    end)
  end
end

return abort
