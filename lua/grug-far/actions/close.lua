--- closes the buffer, thus freeing resources
---@param params { context: GrugFarContext }
local function close(params)
  local context = params.context
  local state = context.state

  local runningTask = nil
  for task_name, abort_fn in pairs(state.abort) do
    -- note: we only care about warning user when aborting stuff other than a search
    if task_name ~= 'search' and abort_fn then
      runningTask = task_name
    end
  end

  -- TODO (sbadragan): should we add a forceAbort option?
  if runningTask then
    local choice = vim.fn.confirm(
      runningTask .. ' task will be aborted. Are you sure you want to close grug-far buffer?',
      '&yes\n&cancel'
    )
    if choice == 2 then
      return
    end
  end

  vim.cmd('stopinsert | bdelete')
end

return close
