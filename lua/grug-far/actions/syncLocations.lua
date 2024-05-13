local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')
local utils = require('grug-far/utils')
local uv = vim.loop

-- note: this could use libuv and do async io if we find we need the perf boost
local function writeChangedFile(params)
  local changedFile = params.changedFile
  local on_done = params.on_done
  local file = changedFile.filename

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

  local changedLines = changedFile.changedLines
  for i = 1, #changedLines do
    local changedLine = changedLines[i]
    local lnum = changedLine.lnum
    if not lines[lnum] then
      on_done('File does not have edited row anymore: ' .. file)
      return
    end

    lines[lnum] = changedLine.newLine
  end

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
  local changedFiles = vim.deepcopy(params.changedFiles)
  local reportProgress = params.reportProgress
  local on_finish = params.on_finish
  local engagedWorkers = 0
  local errorMessages = ''

  local function syncNextChangedFile()
    local changedFile = table.remove(changedFiles)
    if changedFile == nil then
      if engagedWorkers == 0 then
        on_finish(#errorMessages > 0 and 'error' or 'success', errorMessages)
      end
      return
    end

    engagedWorkers = engagedWorkers + 1
    writeChangedFile({
      changedFile = changedFile,
      on_done = vim.schedule_wrap(function(err)
        if err then
          -- optimistically try to continue
          errorMessages = errorMessages .. '\n' .. err
        end

        if reportProgress then
          reportProgress()
        end
        engagedWorkers = engagedWorkers - 1
        syncNextChangedFile()
      end)
    })
  end

  for _ = 1, context.options.maxWorkers do
    syncNextChangedFile()
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

local function isMultilineSearchReplace(context)
  local inputs = context.state.inputs
  local multilineFlags = { '--multiline', '-U' }
  if #inputs.flags > 0 then
    for flag in string.gmatch(inputs.flags, "%S+") do
      if utils.isBlacklistedFlag(flag, multilineFlags) then
        return true
      end
    end
  end
end


local function syncLocations(params)
  local buf = params.buf
  local context = params.context
  local state = context.state
  local startTime = uv.now()
  if isMultilineSearchReplace(context) then
    state.actionMessage = 'sync disabled for multline search/replace!'
    renderResultsHeader(buf, context)
    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
    return
  end

  local extmarks = vim.api.nvim_buf_get_extmarks(0, context.locationsNamespace, 0, -1, {})
  local changedFilesByFilename = {}
  for i = 1, #extmarks do
    local markId, row = unpack(extmarks[i])
    local location = context.state.resultLocationByExtmarkId[markId]

    if location and location.rgResultLine then
      local bufline = unpack(vim.api.nvim_buf_get_lines(buf, row, row + 1, true))
      if bufline ~= location.rgResultLine then
        local numColPrefix = string.sub(location.rgResultLine, 1, location.rgColEndIndex + 1)
        if vim.startswith(bufline, numColPrefix) then
          local changedFile = changedFilesByFilename[location.filename]
          if not changedFile then
            changedFilesByFilename[location.filename] = {
              filename = location.filename,
              changedLines = {}
            }
            changedFile = changedFilesByFilename[location.filename]
          end
          table.insert(changedFile.changedLines, {
            lnum = location.lnum,
            -- note, skips (:)
            newLine = string.sub(bufline, location.rgColEndIndex + 2, -1)
          })
        end
      end
    end
  end

  local changedFiles = {}
  for _, f in pairs(changedFilesByFilename) do
    table.insert(changedFiles, f)
  end

  if #changedFiles == 0 then
    state.actionMessage = 'no changes to sync!'
    renderResultsHeader(buf, context)
    vim.notify('grug-far: no changes to sync!', vim.log.levels.INFO)
    return
  end

  local changesCount = 0
  local changesTotal = #changedFiles

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

    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.ERROR)
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

    vim.notify('grug-far: synced changes!', vim.log.levels.INFO)
  end)

  syncChangedLines({
    context = context,
    changedFiles = changedFiles,
    reportProgress = reportSyncedFilesUpdate,
    on_finish = on_finish_all
  })
end

return syncLocations
