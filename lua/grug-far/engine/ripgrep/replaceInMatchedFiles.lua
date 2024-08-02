local fetchReplacedFileContent = require('grug-far/engine/ripgrep/fetchReplacedFileContent')
local utils = require('grug-far/utils')

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
      if status == nil then
        -- aborted
        return on_done(nil)
      end

      if status == 'success' and content then
        return utils.overwriteFileAsync(file, content, function(err)
          if err then
            return on_done('Could not write: ' .. file .. '\n' .. err)
          end

          on_done(nil)
        end)
      end

      return on_done(nil)
    end,
  })
end

---@class replaceInMatchedFilesParams
---@field context GrugFarContext
---@field files string[]
---@field report_progress fun(count: integer)
---@field on_finish fun(status: GrugFarStatus, errorMessage: string | nil)

--- performs replacement in given matched file
---@param params replaceInMatchedFilesParams
local function replaceInMatchedFiles(params)
  local context = params.context
  local files = vim.deepcopy(params.files)
  local report_progress = params.report_progress
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

        report_progress(1)
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

return replaceInMatchedFiles
