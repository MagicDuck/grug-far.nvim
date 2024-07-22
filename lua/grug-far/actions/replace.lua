local fetchFilesWithMatches = require('grug-far/rg/fetchFilesWithMatches')
local fetchReplacedFileContent = require('grug-far/rg/fetchReplacedFileContent')
local getArgs = require('grug-far/rg/getArgs')
local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')
local utils = require('grug-far/utils')
local history = require('grug-far/history')
local uv = vim.uv

--- performs replacement in given file
---@param params { context: GrugFarContext, file: string, on_done: fun(errorMessage: string | nil) }
---@return fun() | nil abort
local function replaceInFile(params)
  local context = params.context
  local state = context.state
  local file = params.file
  local on_done = params.on_done

  return fetchReplacedFileContent({
    inputs = state.inputs,
    options = context.options,
    file = file,
    on_finish = function(status, errorMessage, content)
      if status == 'error' then
        return on_done(errorMessage)
      end

      utils.overwriteFileAsync(file, content, function(err)
        if err then
          return on_done('Could not write: ' .. file .. '\n' .. err)
        end

        on_done(nil)
      end)
    end,
  })
end

---@class replaceInMatchedFilesParams
---@field context GrugFarContext
---@field files string[]
---@field reportProgress fun()
---@field on_finish fun(status: GrugFarStatus, errorMessage: string | nil)

--- performs replacement in given matched file
---@param params replaceInMatchedFilesParams
local function replaceInMatchedFiles(params)
  local context = params.context
  local files = vim.deepcopy(params.files)
  local reportProgress = params.reportProgress
  local on_finish = params.on_finish
  local engagedWorkers = 0
  local errorMessages = ''
  local isAborted = false
  local abortByFile = {}

  local function abortAll()
    isAborted = true
    for _, abort in pairs(abortByFile) do
      if abort then
        abort()
      end
    end
  end

  local function replaceNextFile()
    if isAborted then
      files = {}
    end

    local file = table.remove(files)
    if file == nil then
      if engagedWorkers == 0 then
        if isAborted then
          on_finish(nil, nil)
        else
          on_finish(#errorMessages > 0 and 'error' or 'success', errorMessages)
        end
      end
      return
    end

    engagedWorkers = engagedWorkers + 1
    abortByFile[file] = replaceInFile({
      file = file,
      context = context,
      on_done = vim.schedule_wrap(function(err)
        if err then
          -- optimistically try to continue
          errorMessages = errorMessages .. '\n' .. err
        end

        abortByFile[file] = nil

        reportProgress()
        engagedWorkers = engagedWorkers - 1
        replaceNextFile()
      end),
    })
  end

  for _ = 1, context.options.maxWorkers do
    replaceNextFile()
  end

  return abortAll
end

--- gets action message to display
---@param err string | nil
---@param count? integer
---@param total? integer
---@param time? integer
---@return string
local function getActionMessage(err, count, total, time)
  local msg = 'replace '
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

--- are we replacing matches with the empty string?
---@param args string[]
---@return boolean
local function isEmptyStringReplace(args)
  local replaceEqArg = '--replace='
  for i = #args, 1, -1 do
    local arg = args[i]
    if vim.startswith(arg, replaceEqArg) then
      if #arg > #replaceEqArg then
        return false
      else
        return true
      end
    end
  end

  return true
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

  local reportMatchingFilesUpdate = function(files)
    if state.bufClosed then
      return
    end

    state.status = 'progress'
    state.progressCount = state.progressCount + 1
    filesTotal = filesTotal + #files
    state.actionMessage = getActionMessage(nil, filesCount, filesTotal)
    renderResultsHeader(buf, context)
    resultsList.throttledForceRedrawBuffer(buf)
  end

  local reportReplacedFilesUpdate = function()
    if state.bufClosed then
      return
    end

    state.status = 'progress'
    state.progressCount = state.progressCount + 1
    filesCount = filesCount + 1
    state.actionMessage = getActionMessage(nil, filesCount, filesTotal)
    renderResultsHeader(buf, context)
    resultsList.throttledForceRedrawBuffer(buf)
  end

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
      state.actionMessage = getActionMessage(
        nil,
        filesCount,
        filesCount,
        context.options.reportDuration and time or nil
      )
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

  local args = getArgs(context.state.inputs, context.options, {})
  if not args then
    on_finish_all(nil, nil, 'replace cannot work with the current arguments!')
    return
  end

  if isEmptyStringReplace(args) then
    local choice = vim.fn.confirm('Replace matches with empty string?', '&yes\n&cancel')
    if choice == 2 then
      on_finish_all(nil, nil, 'replace with empty string canceled!')
      return
    end
  end

  startTime = uv.now()
  state.abort.replace = fetchFilesWithMatches({
    inputs = context.state.inputs,
    options = context.options,
    on_fetch_chunk = reportMatchingFilesUpdate,
    on_finish = function(status, errorMessage, files, blacklistedArgs)
      if not status then
        on_finish_all(
          nil,
          nil,
          blacklistedArgs
              and 'replace cannot work with flags: ' .. vim.fn.join(blacklistedArgs, ', ')
            or nil
        )
        return
      elseif status == 'error' then
        on_finish_all(status, errorMessage)
        return
      end

      state.abort.replace = replaceInMatchedFiles({
        files = files,
        context = context,
        reportProgress = reportReplacedFilesUpdate,
        reportError = reportError,
        on_finish = on_finish_all,
      })
    end,
  })
end

return replace
