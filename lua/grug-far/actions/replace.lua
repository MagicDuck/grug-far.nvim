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
  local buf = params.buf
  local context = params.context
  local state = context.state
  local files = params.files
  local reportProgress = params.reportProgress
  local reportError = params.reportError
  local errorMessages = ''

  local on_finish_all = vim.schedule_wrap(function(status, errorMessage)
    if status == 'error' then
      reportError(errorMessage)
      return
    end

    state.status = status
    state.progressCount = nil
    renderResultsHeader(buf, context)
  end)

  if #files == 0 then
    on_finish_all('success')
  end


  -- TODO (sbadragan): make it do multiple in parallel
  local function replaceInFileAtIndex(index)
    replaceInFile({
      file = files[index],
      context = context,
      on_done = function(err)
        if err then
          -- optimistically try to continue
          errorMessages = errorMessages .. '\n' .. err
        end

        reportProgress(index)

        if (index < #files) then
          replaceInFileAtIndex(index + 1)
        else
          on_finish_all(#errorMessages > 0 and 'error' or 'success', errorMessages)
        end
      end
    })
  end

  replaceInFileAtIndex(1)
end

-- TODO (sbadragan): need to figure where to show this in the UI, aborting, etc
-- possibly in the results list header, show "Applying changes, buffer not modifiable meanwhile"
-- and set nomodifiable for buffer
-- need to call this with proper params from somewhere
local function replace(params)
  local buf = params.buf
  local context = params.context
  local state = context.state

  -- initiate replace in UI
  vim.schedule(function()
    state.status = 'progress'
    state.progressCount = 0
    renderResultsHeader(buf, context)
  end)

  local reportProgress = vim.schedule_wrap(function()
    state.status = 'progress'
    state.progressCount = state.progressCount + 1
    renderResultsHeader(buf, context)
  end)

  local reportError = function(errorMessage)
    state.status = 'error'
    state.progressCount = nil
    resultsList.appendError(buf, context, errorMessage)
    renderResultsHeader(buf, context)
  end

  fetchFilesWithMatches({
    inputs = context.state.inputs,
    options = context.options,
    on_fetch_chunk = reportProgress,
    on_finish = vim.schedule_wrap(function(status, errorMessage, files)
      if status == 'error' then
        reportError(errorMessage)
        return
      end

      replaceInMatchedFiles({
        buf = buf,
        files = files,
        context = context,
        reportProgress = reportProgress,
        reportError = reportError
      })
    end)
  })
end

return replace
