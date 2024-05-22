local fetchFilesWithMatches = require('grug-far/rg/fetchFilesWithMatches')
local fetchReplacedFileContent = require('grug-far/rg/fetchReplacedFileContent')
local getArgs = require('grug-far/rg/getArgs')
local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')
local utils = require('grug-far/utils')
local uv = vim.loop

--- performs replacement in given file
---@param params { context: GrugFarContext, file: string, on_done: fun(errorMessage: string | nil) }
local function replaceInFile(params)
  local context = params.context
  local state = context.state
  local file = params.file
  local on_done = params.on_done

  fetchReplacedFileContent({
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

  local function replaceNextFile()
    local file = table.remove(files)
    if file == nil then
      if engagedWorkers == 0 then
        on_finish(#errorMessages > 0 and 'error' or 'success', errorMessages)
      end
      return
    end

    engagedWorkers = engagedWorkers + 1
    replaceInFile({
      file = file,
      context = context,
      on_done = vim.schedule_wrap(function(err)
        if err then
          -- optimistically try to continue
          errorMessages = errorMessages .. '\n' .. err
        end

        reportProgress()
        engagedWorkers = engagedWorkers - 1
        replaceNextFile()
      end),
    })
  end

  for _ = 1, context.options.maxWorkers do
    replaceNextFile()
  end
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

  if count == total and total ~= 0 and time then
    return msg .. 'completed in ' .. time .. 'ms!'
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
  local filesCount = 0
  local filesTotal = 0
  local startTime

  -- initiate replace in UI
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  state.status = 'progress'
  state.progressCount = 0
  state.actionMessage = getActionMessage(nil, filesCount, filesTotal)
  renderResultsHeader(buf, context)

  local reportMatchingFilesUpdate = vim.schedule_wrap(function(files)
    state.status = 'progress'
    state.progressCount = state.progressCount + 1
    filesTotal = filesTotal + #files
    state.actionMessage = getActionMessage(nil, filesCount, filesTotal)
    renderResultsHeader(buf, context)
  end)

  local reportReplacedFilesUpdate = vim.schedule_wrap(function()
    state.status = 'progress'
    state.progressCount = state.progressCount + 1
    filesCount = filesCount + 1
    state.actionMessage = getActionMessage(nil, filesCount, filesTotal)
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
      or getActionMessage(nil, filesCount, filesCount, time)
    renderResultsHeader(buf, context)

    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
  end)

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
  fetchFilesWithMatches({
    inputs = context.state.inputs,
    options = context.options,
    on_fetch_chunk = reportMatchingFilesUpdate,
    on_finish = vim.schedule_wrap(function(status, errorMessage, files, blacklistedArgs)
      if not status then
        on_finish_all(
          nil,
          nil,
          blacklistedArgs
              and 'replace cannot work with flags: ' .. vim.fn.join(blacklistedArgs, ', ')
            or 'replace aborted!'
        )
        return
      elseif status == 'error' then
        on_finish_all(status, errorMessage)
        return
      end

      replaceInMatchedFiles({
        files = files,
        context = context,
        reportProgress = reportReplacedFilesUpdate,
        reportError = reportError,
        on_finish = on_finish_all,
      })
    end),
  })
end

return replace
