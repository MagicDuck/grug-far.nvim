local utils = require('grug-far/utils')

--- performs sync for given changed file
---@param params { changedFile: ChangedFile, on_done: fun(errorMessage: string?) }
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

---@class SyncChangedFilesParams
---@field options GrugFarOptions
---@field changedFiles ChangedFile[]
---@field report_progress fun(count: integer)
---@field on_finish fun(status: GrugFarStatus, errorMessage: string | nil)

--- sync given changed files
---@param params SyncChangedFilesParams
---@return fun() abort
local function syncChangedFiles(params)
  local changedFiles = vim.deepcopy(params.changedFiles)
  local report_progress = params.report_progress
  local on_finish = vim.schedule_wrap(params.on_finish)
  local engagedWorkers = 0
  local errorMessages = ''
  local isAborted = false

  local function abortAll()
    isAborted = true
  end

  local function syncNextChangedFile()
    if isAborted then
      changedFiles = {}
    end

    local changedFile = table.remove(changedFiles)
    if changedFile == nil then
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
    writeChangedFile({
      changedFile = changedFile,
      on_done = vim.schedule_wrap(function(err)
        if err then
          -- optimistically try to continue
          errorMessages = errorMessages .. '\n' .. err
        end

        if report_progress then
          report_progress(1)
        end
        engagedWorkers = engagedWorkers - 1
        syncNextChangedFile()
      end),
    })
  end

  for _ = 1, params.options.maxWorkers do
    syncNextChangedFile()
  end

  return abortAll
end

return syncChangedFiles
