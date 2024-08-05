local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')
local history = require('grug-far/history')
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
---@param params { buf: integer, context: GrugFarContext }
local function replace(params)
  local buf = params.buf
  local context = params.context
  local state = context.state
  local abort = state.abort
  local filesCount = 0
  local filesTotal = 0
  local startTime

  if abort.replace then
    vim.notify('grug-far: replace already in progress', vim.log.levels.INFO)
    return
  end

  if abort.sync then
    vim.notify('grug-far: sync in progress', vim.log.levels.INFO)
    return
  end

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

  local on_finish_all = function(status, errorMessage, customActionMessage)
    if state.bufClosed then
      return
    end

    vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
    state.abort.replace = nil

    if status == 'error' then
      reportError(errorMessage)
      return
    end

    if errorMessage and #errorMessage > 0 then
      resultsList.appendWarning(buf, context, errorMessage)
    end

    state.status = status
    vim.cmd.checktime()

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
      return
    end

    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)

    local autoSave = context.options.history.autoSave
    if autoSave.enabled and autoSave.onReplace then
      history.addHistoryEntry(context)
    end
  end

  startTime = uv.now()
  state.abort.replace = context.engine.replace({
    inputs = context.state.inputs,
    options = context.options,

    report_progress = function(update)
      if state.bufClosed then
        return
      end

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
      resultsList.throttledForceRedrawBuffer(buf)
    end,
    on_finish = on_finish_all,
  })
end

return replace
