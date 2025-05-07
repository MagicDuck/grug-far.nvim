local fetchReplacedFileContent = require('grug-far.engine.ripgrep.fetchReplacedFileContent')
local utils = require('grug-far.utils')
local fetchCommandOutput = require('grug-far.engine.fetchCommandOutput')
local argUtils = require('grug-far.engine.ripgrep.argUtils')
local getArgs = require('grug-far.engine.ripgrep.getArgs')
local parseResults = require('grug-far.engine.ripgrep.parseResults')

---@class grug.far.replaceInFileParams
---@field inputs grug.far.Inputs
---@field options grug.far.Options
---@field replacement_eval_fn fun(...): (string?, string?)
---@field file string
---@field on_done fun(errorMessage: string?)

--- performs replacement in given file
---@param params grug.far.replaceInFileParams
---@return fun()? abort
local function replaceInFile(params)
  local file = params.file
  local on_done = params.on_done
  return fetchReplacedFileContent({
    inputs = params.inputs,
    options = params.options,
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

--- performs replacement in given file with eval
---@param params grug.far.replaceInFileParams
---@return fun()? abort
local function replaceInFileWithEval(params)
  local file = params.file
  local on_done = params.on_done
  local replacement_eval_fn = params.replacement_eval_fn

  local inputs = vim.deepcopy(params.inputs)
  inputs.paths = ''
  local args = getArgs(inputs, params.options, { '--json' })
  args = argUtils.stripReplaceArgs(args)
  if args then
    table.insert(args, params.file)
  end

  local json_data = {}
  local chunk_error = nil
  local abort
  abort = fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = args,
    on_fetch_chunk = function(data)
      if chunk_error then
        return
      end

      local json_list = utils.str_to_json_list(data)
      for _, entry in ipairs(json_list) do
        if entry.type == 'match' then
          for _, submatch in ipairs(entry.data.submatches) do
            local replacementText, err = replacement_eval_fn(submatch.match.text)
            if err then
              chunk_error = err
              if abort then
                abort()
              end
              return
            end
            submatch.replacement = { text = replacementText }
          end
          table.insert(json_data, entry)
        end
      end
    end,
    on_finish = function(status, errorMessage)
      if status == 'error' then
        return on_done(errorMessage)
      end

      if chunk_error then
        return on_done(chunk_error)
      end

      if status == 'success' and #json_data > 0 then
        return utils.readFileAsync(file, function(err1, contents)
          if err1 then
            return on_done('Could not read: ' .. file .. '\n' .. err1)
          end

          local new_contents = parseResults.getReplacedContents(contents, json_data)
          return utils.overwriteFileAsync(file, new_contents, function(err2)
            if err2 then
              return on_done('Could not write: ' .. file .. '\n' .. err2)
            end

            on_done(nil)
          end)
        end)
      end

      return on_done(nil)
    end,
  })

  return abort
end

--- performs replacement in given matched file
---@param params {
--- inputs: grug.far.Inputs,
--- options: grug.far.Options,
--- replacement_eval_fn: fun(...): (string?, string?),
--- files: string[],
--- report_progress: fun(count: integer),
--- on_finish: fun(status: grug.far.Status, errorMessage: string?),
--- }
local function replaceInMatchedFiles(params)
  local files = vim.deepcopy(params.files)
  local report_progress = params.report_progress
  local on_finish = params.on_finish
  local engagedWorkers = 0
  local errorMessage = nil
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

  local replace_in_file = params.replacement_eval_fn and replaceInFileWithEval or replaceInFile

  local function replaceNextFile()
    if isAborted then
      files = {}
    end

    local file = table.remove(files)
    if file == nil then
      if engagedWorkers == 0 then
        if errorMessage then
          on_finish('error', errorMessage)
        elseif isAborted then
          on_finish(nil, nil)
        else
          on_finish('success', nil)
        end
      end
      return
    end

    engagedWorkers = engagedWorkers + 1
    abortByFile[file] = replace_in_file({
      file = file,
      inputs = params.inputs,
      options = params.options,
      replacement_eval_fn = params.replacement_eval_fn,
      on_done = vim.schedule_wrap(function(err)
        abortByFile[file] = nil
        if err then
          errorMessage = err
          abortAll()
        else
          report_progress(1)
        end

        engagedWorkers = engagedWorkers - 1
        replaceNextFile()
      end),
    })
  end

  for _ = 1, params.options.maxWorkers do
    replaceNextFile()
  end

  return abortAll
end

return replaceInMatchedFiles
