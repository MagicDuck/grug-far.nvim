local renderResultsHeader = require('grug-far.render.resultsHeader')
local resultsList = require('grug-far.render.resultsList')
local uv = vim.uv

--- gets action message to display
---@param err string | nil
---@param count? integer
---@param total? integer
---@param time? integer
---@return string
local function getActionMessage(err, count, total, time)
  local msg = 'sync '
  if err then
    return msg .. 'failed!'
  end

  if count == total and total ~= 0 then
    if time then
      return msg .. 'completed in ' .. time .. 'ms!'
    else
      return msg .. 'completed!'
    end
  end

  return msg .. count .. ' / ' .. total .. ' (buffer temporarily not modifiable)'
end

--- figure out which files changed and how
--- note startRow / endRow are zero-based
---@param buf integer
---@param context GrugFarContext
---@param startRow integer
---@param endRow integer
---@return ChangedFile[]
local function getChangedFiles(buf, context, startRow, endRow)
  local isReplacing = context.engine.isSearchWithReplacement(context.state.inputs, context.options)

  local changedFilesByFilename = {}
  resultsList.forEachChangedLocation(buf, context, startRow, endRow, function(location, newLine)
    local changedFile = changedFilesByFilename[location.filename]
    if not changedFile then
      changedFilesByFilename[location.filename] = {
        filename = location.filename,
        changedLines = {},
      }
      changedFile = changedFilesByFilename[location.filename]
    end

    table.insert(changedFile.changedLines, {
      lnum = location.lnum,
      newLine = newLine,
    })
  end, isReplacing)

  local changedFiles = {}
  for _, f in pairs(changedFilesByFilename) do
    table.insert(changedFiles, f)
  end

  return changedFiles
end

---@class SyncParams
---@field buf integer
---@field context GrugFarContext
---@field startRow integer
---@field endRow integer
---@field on_success? fun()
---@field shouldNotifyOnComplete? boolean defaults to true

--- performs sync of lines in results area with corresponding original file locations
---@param params SyncParams
local function sync(params)
  local buf = params.buf
  local context = params.context
  local startRow = params.startRow
  local endRow = params.endRow
  local on_success = params.on_success
  local shouldNotifyOnComplete = params.shouldNotifyOnComplete ~= false
  local state = context.state
  local abort = state.abort

  if abort.sync then
    vim.notify('grug-far: sync already in progress', vim.log.levels.INFO)
    return
  end

  if abort.replace then
    vim.notify('grug-far: replace in progress', vim.log.levels.INFO)
    return
  end

  if abort.search then
    vim.notify('grug-far: search in progress', vim.log.levels.INFO)
    return
  end

  if not context.engine.isSyncSupported() then
    state.actionMessage = 'sync operation not supported by current engine!'
    renderResultsHeader(buf, context)
    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
    return
  end

  local startTime = uv.now()
  local changedFiles = getChangedFiles(buf, context, startRow, endRow)

  if #changedFiles == 0 then
    state.actionMessage = 'no changes to sync!'
    renderResultsHeader(buf, context)
    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
    return
  end

  local changesCount = 0
  local changesTotal = #changedFiles

  -- initiate sync in UI
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  state.status = 'progress'
  state.progressCount = 0
  state.actionMessage = getActionMessage(nil, changesCount, changesTotal)
  renderResultsHeader(buf, context)

  local reportError = function(errorMessage)
    vim.api.nvim_set_option_value('modifiable', true, { buf = buf })

    state.status = 'error'
    state.actionMessage = getActionMessage(errorMessage)
    resultsList.setError(buf, context, errorMessage)
    renderResultsHeader(buf, context)

    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
  end

  state.abort.sync = context.engine.sync({
    inputs = context.state.inputs,
    options = context.options,
    changedFiles = changedFiles,
    report_progress = function(update)
      if state.bufClosed then
        return
      end

      state.status = 'progress'
      state.progressCount = state.progressCount + 1
      if update.type == 'update_count' then
        changesCount = changesCount + 1
      end
      state.actionMessage = getActionMessage(nil, changesCount, changesTotal)
      renderResultsHeader(buf, context)
      resultsList.throttledForceRedrawBuffer(buf, context)
    end,
    on_finish = function(status, errorMessage, customActionMessage)
      if state.bufClosed then
        return
      end

      vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
      state.abort.sync = nil

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
        state.actionMessage = 'sync aborted at ' .. changesCount .. ' / ' .. changesTotal
      elseif status == nil and customActionMessage then
        state.actionMessage = customActionMessage
      else
        local time = uv.now() - startTime
        -- not passing in total as 3rd arg cause of paranoia if counts don't end up matching
        state.actionMessage = getActionMessage(
          nil,
          changesCount,
          changesCount,
          context.options.reportDuration and time or nil
        )
      end

      renderResultsHeader(buf, context)

      vim.schedule(function()
        resultsList.markUnsyncedLines(buf, context, startRow, endRow, true)
      end)

      if wasAborted or status == nil then
        return
      end

      if shouldNotifyOnComplete then
        vim.notify('grug-far: synced changes!', vim.log.levels.INFO)
      end
      if on_success then
        on_success()
      end
    end,
  })
end

return sync
