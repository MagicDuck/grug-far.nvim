local fetchCommandOutput = require('grug-far.engine.fetchCommandOutput')
local utils = require('grug-far.utils')
local getArgs = require('grug-far.engine.astgrep.getArgs')
local blacklistedReplaceFlags = require('grug-far.engine.astgrep.blacklistedReplaceFlags')
local fetchFilteredFilesList = require('grug-far.engine.ripgrep.fetchFilteredFilesList')
local runWithChunkedFiles = require('grug-far.engine.runWithChunkedFiles')
local argUtils = require('grug-far.engine.astgrep.argUtils')
local parseResults = require('grug-far.engine.astgrep.parseResults')
local ProcessingQueue = require('grug-far.engine.ProcessingQueue')

local M = {}

---@params params EngineReplaceParams
---@params args string[]
---@params eval_fn fun(...): (string?, string?)
---@return fun()? abort
local function replace_with_eval(params, args, eval_fn)
  local on_finish = vim.schedule_wrap(params.on_finish)
  local abortSearch = nil
  local processingQueue = nil

  local abort = function()
    if processingQueue then
      processingQueue:stop()
    end
    if abortSearch then
      abortSearch()
    end
  end

  local search_args = vim.deepcopy(args)
  table.insert(search_args, '--json=stream')

  processingQueue = ProcessingQueue.new(function(file_matches, on_done)
    local file = file_matches[1].file
    utils.readFileAsync(file, function(err1, contents)
      if err1 then
        return on_finish('error', 'Could not read: ' .. file .. '\n' .. err1)
      end

      local new_contents = parseResults.getReplacedContents(contents, file_matches)
      return utils.overwriteFileAsync(file, new_contents, function(err2)
        if err2 then
          return on_finish('error', 'Could not write: ' .. file .. '\n' .. err2)
        end

        on_done()
      end)
    end)
  end)

  local matches = {}
  local chunk_error = nil
  abortSearch = fetchCommandOutput({
    cmd_path = params.options.engines.astgrep.path,
    args = search_args,
    on_fetch_chunk = function(data)
      if chunk_error then
        return
      end

      local err = parseResults.json_decode_matches(matches, data, eval_fn)
      if err then
        chunk_error = err
        if abort then
          abort()
        end
        return
      end

      -- note: we split off last file matches to ensure all matches for a file are processed
      -- at once. This helps with applying replacements
      local before, after = parseResults.split_last_file_matches(matches)
      matches = after

      for _, file_matches in ipairs(parseResults.split_matches_per_file(before)) do
        processingQueue:push(file_matches)
      end
    end,
    on_finish = function(status, errorMessage)
      if chunk_error then
        status = 'error'
        errorMessage = chunk_error
      end

      if status == 'success' and #matches > 0 then
        -- do the last few
        for _, file_matches in ipairs(parseResults.split_matches_per_file(matches)) do
          processingQueue:push(file_matches)
        end
        matches = {}
      end

      if status == 'success' then
        processingQueue:on_finish(function()
          processingQueue:stop()
          on_finish(status, errorMessage)
        end)
      else
        processingQueue:stop()
        on_finish(status, errorMessage)
      end
    end,
  })

  return abort
end

--- does replace
---@param params EngineReplaceParams
---@return fun()? abort
function M.replace(params)
  local report_progress = params.report_progress
  local on_finish = params.on_finish

  local extraArgs = {
    '--update-all',
  }
  local args, blacklistedArgs =
    getArgs(params.inputs, params.options, extraArgs, blacklistedReplaceFlags, true)

  if blacklistedArgs and #blacklistedArgs > 0 then
    on_finish(nil, nil, 'replace cannot work with flags: ' .. vim.fn.join(blacklistedArgs, ', '))
    return
  end

  if not args then
    on_finish(nil, nil, 'replace cannot work with the current arguments!')
    return
  end

  if #params.inputs.replacement == 0 then
    local choice = vim.fn.confirm('Replace matches with empty string?', '&yes\n&cancel')
    if choice ~= 1 then
      on_finish(nil, nil, 'replace with empty string canceled!')
      return
    end
  end

  local eval_fn
  if params.replacementInterpreter then
    local interpreterError
    eval_fn, interpreterError =
      params.replacementInterpreter.get_eval_fn(params.inputs.replacement, { 'match', 'vars' })
    if not eval_fn then
      params.on_finish('error', interpreterError)
      return
    end
    args = argUtils.stripReplaceArgs(args)
  end

  report_progress({
    type = 'message',
    message = 'replacing... (buffer temporarily not modifiable)',
  })

  local on_abort = nil
  local function abort()
    if on_abort then
      on_abort()
    end
  end

  local filesFilter = params.inputs.filesFilter
  if filesFilter and #filesFilter > 0 then
    -- ast-grep currently does not support --glob type functionality
    -- see see https://github.com/ast-grep/ast-grep/issues/1062
    -- this if-branch uses rg to get the files and can be removed if that is implemented
    on_abort = fetchFilteredFilesList({
      inputs = params.inputs,
      options = params.options,
      report_progress = function() end,
      on_finish = function(status, errorMessage, files)
        if not status then
          on_finish(nil, nil, nil)
          return
        elseif status == 'error' then
          on_finish(status, errorMessage)
          return
        end

        on_abort = runWithChunkedFiles({
          files = files,
          chunk_size = 200,
          options = params.options,
          run_chunk = function(chunk, on_done)
            local chunk_args = vim.deepcopy(args)
            for _, file in ipairs(vim.split(chunk, '\n')) do
              table.insert(chunk_args, file)
            end

            local on_finish_chunk = function(_, _errorMessage)
              return on_done((_errorMessage and #_errorMessage > 0) and _errorMessage or nil)
            end

            if eval_fn then
              return replace_with_eval({
                inputs = params.inputs,
                options = params.options,
                report_progress = report_progress,
                on_finish = on_finish_chunk,
              }, chunk_args, eval_fn)
            else
              return fetchCommandOutput({
                cmd_path = params.options.engines.astgrep.path,
                args = chunk_args,
                on_fetch_chunk = function()
                  -- astgrep does not report progess while replacing
                end,
                on_finish = on_finish_chunk,
              })
            end
          end,
          on_finish = on_finish,
        })
      end,
    })
  else
    if eval_fn then
      on_abort = replace_with_eval(params, args, eval_fn)
    else
      on_abort = fetchCommandOutput({
        cmd_path = params.options.engines.astgrep.path,
        args = args,
        on_fetch_chunk = function()
          -- astgrep does not report progess while replacing
        end,
        on_finish = on_finish,
      })
    end
  end

  return abort
end

return M
