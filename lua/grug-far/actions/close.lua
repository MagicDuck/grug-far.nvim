--- closes the buffer, thus freeing resources
---@param params { context: GrugFarContext, buf: integer }
local function close(params)
  local context = params.context
  local buf = params.buf
  local state = context.state

  local runningTask = nil
  for task_name, abort_fn in pairs(state.abort) do
    -- note: we only care about warning user when aborting stuff other than a search
    if task_name ~= 'search' and abort_fn then
      runningTask = task_name
    end
  end

  if runningTask then
    local choice = vim.fn.confirm(
      runningTask .. ' task will be aborted. Are you sure you want to close grug-far buffer?',
      '&yes\n&cancel'
    )
    if choice == 2 then
      return
    end
  end

  local win = vim.fn.bufwinid(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
  if win ~= -1 then
    vim.fn.win_execute(win, 'quit!')
  end
end

return close
