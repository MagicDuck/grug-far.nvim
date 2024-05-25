local renderResultsHeader = require('grug-far/render/resultsHeader')
local getArgs = require('grug-far/rg/getArgs')
local resultsList = require('grug-far/render/resultsList')
local utils = require('grug-far/utils')
local uv = vim.loop

---@class ChangedLine
---@field lnum integer
---@field newLine string

---@class ChangedFile
---@field filename string
---@field changedLines ChangedLine[]

--- performs sync for given changed file
---@param params { context: GrugFarContext, changedFile: ChangedFile, on_done: fun(errorMessage: string | nil) }
local function writeChangedFile(params)
  local changedFile = params.changedFile
  local on_done = params.on_done
  local file = changedFile.filename

  utils.readFileAsync(file, function(err1, contents)
    if err1 then
      return on_done('Could not read: ' .. file .. '\n' .. err1)
    end

    local lines = vim.split(contents or '', utils.eol)

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

---@class syncChangedFilesParams
---@field context GrugFarContext
---@field changedFiles ChangedFile[]
---@field reportProgress fun()
---@field on_finish fun(status: GrugFarStatus, errorMessage: string | nil)

--- sync given changed files
---@param params syncChangedFilesParams
local function syncChangedFiles(params)
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
      end),
    })
  end

  for _ = 1, context.options.maxWorkers do
    syncNextChangedFile()
  end
end

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

--- is user performing a replacement, ui-wise?
---@param context GrugFarContext
local function isDoingReplace(context)
  local args = getArgs(context.state.inputs, context.options, {})
  if not args then
    return false
  end

  for i = 1, #args do
    if vim.startswith(args[i], '--replace=') or args[i] == '--replace' or args[i] == '-r' then
      return true
    end
  end
end

--- figure out which files changed and how
--- note startRow / endRow are zero-based
---@param buf integer
---@param context GrugFarContext
---@param startRow integer
---@param endRow integer
---@return ChangedFile[]
local function getChangedFiles(buf, context, startRow, endRow)
  local isReplacing = isDoingReplace(context)
  local all_extmarks = vim.api.nvim_buf_get_extmarks(
    0,
    context.locationsNamespace,
    { startRow, 0 },
    { endRow, -1 },
    {}
  )

  -- filter out extraneous extmarks caused by deletion of lines
  local extmarks = resultsList.filterDeletedLinesExtmarks(all_extmarks)

  local changedFilesByFilename = {}
  for i = 1, #extmarks do
    local markId, row = unpack(extmarks[i])

    -- get the associated location info
    local location = context.state.resultLocationByExtmarkId[markId]
    if location and location.text then
      -- get the current text on row
      local bufline = unpack(vim.api.nvim_buf_get_lines(buf, row, row + 1, false))
      local isChanged = isReplacing or bufline ~= location.text
      if bufline and isChanged then
        -- ignore ones where user has messed with row:col: prefix as we can't get actual changed text
        local numColPrefix = string.sub(location.text, 1, location.end_col + 1)
        if vim.startswith(bufline, numColPrefix) then
          local changedFile = changedFilesByFilename[location.filename]
          if not changedFile then
            changedFilesByFilename[location.filename] = {
              filename = location.filename,
              changedLines = {},
            }
            changedFile = changedFilesByFilename[location.filename]
          end

          -- note, skips (:)
          local newLine = string.sub(bufline, location.end_col + 2, -1)
          table.insert(changedFile.changedLines, {
            lnum = location.lnum,
            newLine = newLine,
          })
        end
      end
    end
  end

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
---@field on_success fun()

--- performs sync of lines in results area with corresponding original file locations
---@param params SyncParams
local function sync(params)
  local buf = params.buf
  local context = params.context
  local startRow = params.startRow
  local endRow = params.endRow
  local on_success = params.on_success
  local state = context.state
  local startTime = uv.now()

  if utils.isMultilineSearchReplace(context) then
    state.actionMessage = 'sync disabled for multline search/replace!'
    renderResultsHeader(buf, context)
    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
    return
  end

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
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  state.status = 'progress'
  state.progressCount = 0
  state.actionMessage = getActionMessage(nil, changesCount, changesTotal)
  renderResultsHeader(buf, context)

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

    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
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
    state.actionMessage = status == nil and customActionMessage
      or getActionMessage(
        nil,
        changesCount,
        changesCount,
        context.options.reportDuration and time or nil
      )
    renderResultsHeader(buf, context)

    vim.notify('grug-far: synced changes!', vim.log.levels.INFO)
    if on_success then
      on_success()
    end
  end)

  syncChangedFiles({
    context = context,
    changedFiles = changedFiles,
    reportProgress = reportSyncedFilesUpdate,
    on_finish = on_finish_all,
  })
end

return sync
