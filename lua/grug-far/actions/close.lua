--- closes the buffer, thus freeing resources
---@param params { context: grug.far.Context, buf: integer }
local function close(params)
  local context = params.context
  local buf = params.buf
  local state = context.state

  local runningNonSearchTasks = vim
    .iter(state.tasks)
    :filter(function(task)
      return task.type ~= 'search' and not task.isFinished
    end)
    :totable()

  if #runningNonSearchTasks > 0 then
    local choice = vim.fn.confirm(
      runningNonSearchTasks[1].type
        .. ' task will be aborted. Are you sure you want to close grug-far buffer?',
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
