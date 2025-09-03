local renderResultsHeader = require('grug-far.render.resultsHeader')
local resultsList = require('grug-far.render.resultsList')
local history = require('grug-far.history')
local tasks = require('grug-far.tasks')
local inputs = require('grug-far.inputs')
local uv = vim.uv

--- gets action message to display
---@param err string | nil
---@param count? integer
---@param total? integer
---@param time? integer
---@param reportDuration? boolean
---@return string
local function getActionMessage(err, count, total, time, reportDuration)
  local msg = 'replace '
  if err then
    return msg .. 'failed!'
  end

  if count == total and time ~= nil then
    if reportDuration then
      return msg .. 'completed in ' .. time .. 'ms!'
    else
      return msg .. 'completed!'
    end
  end

  return msg .. count .. ' / ' .. total .. ' (buffer temporarily not modifiable)'
end

--- performs replace
---@param params { buf: integer, context: grug.far.Context }
local function replace(params)
  local buf = params.buf
  local context = params.context
  local state = context.state
  local filesCount = 0
  local filesTotal = 0
  local startTime

  if tasks.hasActiveTasksWithType(context, 'replace') then
    vim.notify('grug-far: replace already in progress', vim.log.levels.INFO)
    return
  end

  if tasks.hasActiveTasksWithType(context, 'sync') then
    vim.notify('grug-far: sync in progress', vim.log.levels.INFO)
    return
  end

  local task = tasks.createTask(context, 'replace')

  -- initiate replace in UI
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  state.status = 'progress'
  state.progressCount = 0
  state.actionMessage = getActionMessage(nil, filesCount, filesTotal)
  renderResultsHeader(buf, context)

  local reportError = function(errorMessage)
    vim.api.nvim_set_option_value('modifiable', true, { buf = buf })

    state.status = 'error'
    state.actionMessage = getActionMessage(errorMessage)
    resultsList.setError(buf, context, errorMessage)
    renderResultsHeader(buf, context)

    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
  end

  local on_finish_all = tasks.task_callback_wrap(
    context,
    task,
    function(status, errorMessage, customActionMessage)
      vim.api.nvim_set_option_value('modifiable', true, { buf = buf })

      if status == 'error' then
        reportError(errorMessage)
        tasks.finishTask(context, task)
        return
      end

      if errorMessage and #errorMessage > 0 then
        resultsList.appendWarning(buf, context, errorMessage)
      end

      state.status = status
      vim.cmd('silent! checktime')

      local wasAborted = status == nil and customActionMessage == nil

      if wasAborted then
        state.actionMessage = 'replace aborted at ' .. filesCount .. ' / ' .. filesTotal
      elseif status == nil and customActionMessage then
        state.actionMessage = customActionMessage
      else
        local time = uv.now() - startTime
        -- not passing in total as 3rd arg cause of paranoia if counts don't end up matching
        state.actionMessage =
          getActionMessage(nil, filesCount, filesCount, time, context.options.reportDuration)
      end

      renderResultsHeader(buf, context)
      if wasAborted then
        tasks.finishTask(context, task)
        return
      end

      vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)

      local autoSave = context.options.history.autoSave
      if autoSave.enabled and autoSave.onReplace then
        history.addHistoryEntry(context, buf)
      end
      tasks.finishTask(context, task)
    end
  )

  startTime = uv.now()
  task.abort = context.engine.replace({
    inputs = inputs.getValues(context, buf),
    options = context.options,
    replacementInterpreter = context.replacementInterpreter,

    report_progress = tasks.task_callback_wrap(context, task, function(update)
      state.status = 'progress'
      state.progressCount = state.progressCount + 1
      if update.type == 'update_total' then
        filesTotal = filesTotal + update.count
        state.actionMessage = getActionMessage(nil, filesCount, filesTotal)
      elseif update.type == 'update_count' then
        filesCount = filesCount + update.count
        state.actionMessage = getActionMessage(nil, filesCount, filesTotal)
      elseif update.type == 'message' then
        state.actionMessage = update.message
      end
      renderResultsHeader(buf, context)
      resultsList.throttledForceRedrawBuffer(buf, context)
    end),
    on_finish = on_finish_all,
  })
end

return replace
