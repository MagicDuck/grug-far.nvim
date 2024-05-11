local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')
local uv = vim.loop

local function writeChangedLine(params)
  local changedLine = params.changedLine
  local on_done = params.on_done
  local file = changedLine.location.filename
  local lnum = changedLine.location.lnum
  local newLine = changedLine.newLine

  local file_handle = io.open(file, 'r')
  if not file_handle then
    on_done('Could not open file: ' .. file)
    return
  end

  local contents = file_handle:read("*a")
  file_handle:close()
  if not contents then
    on_done('Cound not read file: ' .. file)
    return
  end

  local lines = vim.split(contents, "\n")
  if not lines[lnum] then
    on_done('File does not have edited row anymore: ' .. file)
    return
  end

  lines[lnum] = newLine

  file_handle = io.open(file, 'w+')
  if not file_handle then
    on_done('Could not open file: ' .. file)
    return
  end

  local h = file_handle:write(vim.fn.join(lines, "\n"))
  if not h then
    on_done('Cound not write to file: ' .. file)
    return
  end

  file_handle:flush()
  file_handle:close()

  on_done(nil)
end

local function syncChangedLines(params)
  local context = params.context
  local changedLines = vim.deepcopy(params.changedLines)
  local reportProgress = params.reportProgress
  local on_finish = params.on_finish
  local engagedWorkers = 0
  local errorMessages = ''

  local function syncNextChangedLine()
    local changedLine = table.remove(changedLines)
    if changedLine == nil then
      if engagedWorkers == 0 then
        on_finish(#errorMessages > 0 and 'error' or 'success', errorMessages)
      end
      return
    end

    engagedWorkers = engagedWorkers + 1
    writeChangedLine({
      changedLine = changedLine,
      on_done = vim.schedule_wrap(function(err)
        if err then
          -- optimistically try to continue
          errorMessages = errorMessages .. '\n' .. err
        end

        if reportProgress then
          reportProgress()
        end
        engagedWorkers = engagedWorkers - 1
        syncNextChangedLine()
      end)
    })
  end

  for _ = 1, context.options.maxWorkers do
    syncNextChangedLine()
  end
end

local function getActionMessage(err, count, total, time)
  local msg = 'sync '
  if err then
    return msg .. 'failed!'
  end

  if count == total and total ~= 0 and time then
    return msg .. 'completed in ' .. time .. 'ms!'
  end

  return msg .. count .. ' / ' .. total .. ' (buffer temporarily not modifiable)'
end

local function syncLocations(params)
  local buf = params.buf
  local context = params.context
  local state = context.state

  local extmarks = vim.api.nvim_buf_get_extmarks(0, context.locationsNamespace, 0, -1, {})
  local changedLines = {}
  for i = 1, #extmarks do
    local markId, row = unpack(extmarks[i])
    local location = context.state.resultLocationByExtmarkId[markId]

    if location and location.rgResultLine then
      local bufline = unpack(vim.api.nvim_buf_get_lines(buf, row, row + 1, true))
      if bufline ~= location.rgResultLine then
        local numColPrefix = string.sub(location.rgResultLine, 1, location.rgColEndIndex + 1)
        if vim.startswith(bufline, numColPrefix) then
          table.insert(changedLines, {
            location = location,
            -- note, skips (:)
            newLine = string.sub(bufline, location.rgColEndIndex + 2, -1)
          })
        end
      end
    end
  end

  if #changedLines == 0 then
    return
  end

  local changesCount = 0
  local changesTotal = #changedLines
  local startTime = uv.now()

  -- initiate sync in UI
  vim.schedule(function()
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    state.status = 'progress'
    state.progressCount = 0
    state.actionMessage = getActionMessage(nil, changesCount, changesTotal)
    renderResultsHeader(buf, context)
  end)

  local reportSyncedFilesUpdate = vim.schedule_wrap(function()
    state.status = 'progress'
    state.progressCount = state.progressCount + 1
    changesCount = changesCount + 1
    state.actionMessage = getActionMessage(nil, changesCount, changesTotal)
    renderResultsHeader(buf, context)
  end)

  local reportError = function(errorMessage)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)

    state.status = 'error'
    state.actionMessage = getActionMessage(errorMessage)
    resultsList.setError(buf, context, errorMessage)
    renderResultsHeader(buf, context)
  end

  local on_finish_all = vim.schedule_wrap(function(status, errorMessage, customActionMessage)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)

    if status == 'error' then
      reportError(errorMessage)
      return
    end

    state.status = status
    local time = uv.now() - startTime
    -- not passing in total as 3rd arg cause of paranoia if counts don't end up matching
    state.actionMessage = status == nil and customActionMessage or
      getActionMessage(nil, changesCount, changesCount, time)
    renderResultsHeader(buf, context)
  end)

  syncChangedLines({
    context = context,
    changedLines = changedLines,
    reportProgress = reportSyncedFilesUpdate,
    on_finish = on_finish_all
  })
end

return syncLocations
