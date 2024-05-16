local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')
local utils = require('grug-far/utils')
local uv = vim.loop

-- note: this could use libuv and do async io if we find we need the perf boost
local function writeChangedFile(params)
  local changedFile = params.changedFile
  local on_done = params.on_done
  local file = changedFile.filename

  utils.readFileAsync(file, function(err1, contents)
    if err1 then
      return on_done('Could not read: ' .. file .. '\n' .. err1)
    end

    local lines = vim.split(contents, utils.eol)

    local changedLines = changedFile.changedLines
    for i = 1, #changedLines do
      local changedLine = changedLines[i]
      local lnum = changedLine.lnum
      if not lines[lnum] then
        return on_done('File does not have edited row anymore: ' .. file)
      end

      lines[lnum] = changedLine.newLine
    end

    local newContents = table.concat(lines, utils.eol)
    utils.overwriteFileAsync(file, newContents, function(err2)
      if err2 then
        return on_done('Could not write: ' .. file .. '\n' .. err2)
      end

      on_done(nil)
    end)
  end)
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
  local multilineFlags = { '--multiline', '-U', '--multiline-dotall' }
  if #inputs.flags > 0 then
    for flag in string.gmatch(inputs.flags, "%S+") do
      if utils.isBlacklistedFlag(flag, multilineFlags) then
        return true
      end
    end
  end
end

local function isDoingReplace(context)
  local inputs = context.state.inputs
  return #inputs.replacement > 0
end

local function filterDeletedLinesExtmarks(all_extmarks)
  local marksByRow = {}
  for i = 1, #all_extmarks do
    local mark = all_extmarks[i]
    marksByRow[mark[2]] = mark
  end

  local marks = {}
  for _, mark in pairs(marksByRow) do
    table.insert(marks, mark)
  end

  return marks
end

-- note startRow / endRow are zero-based
local function getChangedFiles(buf, context, startRow, endRow)
  local isReplacing = isDoingReplace(context)
  N = context.locationsNamespace
  local all_extmarks = vim.api.nvim_buf_get_extmarks(0, context.locationsNamespace, { startRow, 0 }, { endRow, -1 }, {})

  -- filter out extraneous extmarks caused by deletion of lines
  local extmarks = filterDeletedLinesExtmarks(all_extmarks)

  local changedFilesByFilename = {}
  for i = 1, #extmarks do
    local markId, row = unpack(extmarks[i])

    -- get the associated location info
    local location = context.state.resultLocationByExtmarkId[markId]
    if not (location and location.rgResultLine) then
      goto continue
    end

    -- get the current text on row
    local bufline = unpack(vim.api.nvim_buf_get_lines(buf, row, row + 1, true))
    local isChanged = isReplacing or bufline ~= location.rgResultLine
    if not isChanged then
      goto continue
    end

    -- ignore ones where user has messed with row:col: prefix as we can't get actual changed text
    local numColPrefix = string.sub(location.rgResultLine, 1, location.rgColEndIndex + 1)
    if not vim.startswith(bufline, numColPrefix) then
      goto continue
    end

    local changedFile = changedFilesByFilename[location.filename]
    if not changedFile then
      changedFilesByFilename[location.filename] = {
        filename = location.filename,
        changedLines = {}
      }
      changedFile = changedFilesByFilename[location.filename]
    end

    -- note, skips (:)
    local newLine = string.sub(bufline, location.rgColEndIndex + 2, -1)
    table.insert(changedFile.changedLines, {
      lnum = location.lnum,
      newLine = newLine
    })

    ::continue::
  end

  local changedFiles = {}
  for _, f in pairs(changedFilesByFilename) do
    table.insert(changedFiles, f)
  end


  return changedFiles
end

local function sync(params)
  local buf = params.buf
  local context = params.context
  local startRow = params.startRow
  local endRow = params.endRow
  local state = context.state
  local startTime = uv.now()
  if isMultilineSearchReplace(context) then
    state.actionMessage = 'sync disabled for multline search/replace!'
    renderResultsHeader(buf, context)
    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
    return
  end

  local changedFiles = getChangedFiles(buf, context, startRow, endRow)

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

return sync
