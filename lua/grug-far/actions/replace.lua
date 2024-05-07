local fetchFilesWithMatches = require('grug-far/rg/fetchFilesWithMatches')
local fetchReplacedFileContent = require('grug-far/rg/fetchReplacedFileContent')
local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')

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
        on_done(errorMessage)
        return
      end

      local file_handle = io.open(file, 'w+')
      if not file_handle then
        on_done('Could not open file: ' .. file)
        return
      end

      local h = file_handle:write(content)
      if not h then
        on_done('Cound not write to file: ' .. file)
        return
      end

      file_handle:flush()
      file_handle:close()

      on_done(nil)
    end
  })
end

local function replaceInMatchedFiles(params)
  local context = params.context
  local files = params.files
  local reportProgress = params.reportProgress
  local on_finish = params.on_finish
  local errorMessages = ''

  if #files == 0 then
    on_finish('success')
  end

  -- TODO (sbadragan): make it do multiple in parallel
  local function replaceInFileAtIndex(index)
    replaceInFile({
      file = files[index],
      context = context,
      on_done = vim.schedule_wrap(function(err)
        if err then
          -- optimistically try to continue
          errorMessages = errorMessages .. '\n' .. err
        end

        reportProgress(index)

        if (index < #files) then
          replaceInFileAtIndex(index + 1)
        else
          on_finish(#errorMessages > 0 and 'error' or 'success', errorMessages)
        end
      end)
    })
  end

  replaceInFileAtIndex(1)
end

local function getActionMessage(err, count, total)
  local msg = 'applying replacements'
  if err then
    return msg .. ' failed!'
  end

  if count == total and total ~= 0 then
    return msg .. ' completed!'
  end

  -- TODO (sbadragan): make buf not modifiable
  return msg .. ' ' .. count .. ' / ' .. total .. ' (buffer temporarily not modifiable)'
end

local function replace(params)
  local buf = params.buf
  local context = params.context
  local state = context.state
  local filesCount = 0
  local filesTotal = 0

  -- initiate replace in UI
  vim.schedule(function()
    state.status = 'progress'
    state.progressCount = 0
    state.actionMessage = getActionMessage(nil, filesCount, filesTotal)
    renderResultsHeader(buf, context)
  end)

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
    state.status = 'error'
    state.progressCount = nil
    state.actionMessage = getActionMessage(errorMessage)
    resultsList.appendError(buf, context, errorMessage)
    renderResultsHeader(buf, context)
  end

  local on_finish_all = vim.schedule_wrap(function(status, errorMessage)
    if status == 'error' then
      reportError(errorMessage)
      return
    end

    state.status = status
    state.progressCount = nil
    -- not passing in total as 3rd arg cause of paranoia if counts don't end up matching
    state.actionMessage = getActionMessage(nil, filesCount, filesCount)
    renderResultsHeader(buf, context)
  end)

  fetchFilesWithMatches({
    inputs = context.state.inputs,
    options = context.options,
    on_fetch_chunk = reportMatchingFilesUpdate,
    on_finish = vim.schedule_wrap(function(status, errorMessage, files)
      if status == 'error' then
        reportError(errorMessage)
        return
      end

      replaceInMatchedFiles({
        files = files,
        context = context,
        reportProgress = reportReplacedFilesUpdate,
        reportError = reportError,
        on_finish = on_finish_all
      })
    end)
  })
end

return replace
