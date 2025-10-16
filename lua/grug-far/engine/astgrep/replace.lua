local fetchCommandOutput = require('grug-far.engine.fetchCommandOutput')
local utils = require('grug-far.utils')
local getArgs = require('grug-far.engine.astgrep.getArgs')
local blacklistedReplaceFlags = require('grug-far.engine.astgrep.blacklistedReplaceFlags')
local argUtils = require('grug-far.engine.astgrep.argUtils')
local parseResults = require('grug-far.engine.astgrep.parseResults')
local ProcessingQueue = require('grug-far.engine.ProcessingQueue')
local search = require('grug-far.engine.astgrep.search')
local uv = vim.uv

local M = {}

---@param params grug.far.EngineReplaceParams
---@param args string[]
---@param eval_fn fun(...): (string?, string?)
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

--- replaces in bufrange
---@param params {
--- options: grug.far.Options,
--- args: string[],
--- replacement_eval_fn?: fun(...): (string?, string?),
--- bufrange: grug.far.VisualSelectionInfo,
--- on_finish: fun(status: grug.far.Status, errorMessage: string?),
--- }
local function replaceInBufrange(params)
  local on_finish = params.on_finish
  local replacement_eval_fn = params.replacement_eval_fn
  local bufrange = params.bufrange

  local chunk_error = nil
  local abort
  local stdin = uv.new_pipe()
  local input_text = table.concat(bufrange.lines, utils.eol)
  local search_args = vim.deepcopy(params.args)
  table.insert(search_args, '--json=stream')

  local matches = {}
  abort = fetchCommandOutput({
    cmd_path = params.options.engines.astgrep.path,
    args = search_args,
    stdin = stdin,
    on_fetch_chunk = function(data)
      if chunk_error then
        return
      end

      local err = parseResults.json_decode_matches(matches, data, replacement_eval_fn)
      if err then
        chunk_error = err
        return
      end
    end,
    on_finish = function(status, errorMessage)
      if status == 'error' then
        return on_finish('error', errorMessage)
      end

      if chunk_error then
        return on_finish(chunk_error)
      end

      if status == 'success' and #matches > 0 then
        local new_text = parseResults.getReplacedContents(input_text, matches)

        utils.writeInBufrange(bufrange, vim.split(new_text, utils.eol))
      end

      return on_finish('success')
    end,
  })

  uv.write(stdin, input_text, function()
    uv.shutdown(stdin)
  end)

  return abort
end

--- does replace
---@param params grug.far.EngineReplaceParams
---@return fun()? abort
function M.replace(params)
  local report_progress = params.report_progress
  local on_finish = params.on_finish
  local inputs = vim.deepcopy(params.inputs)
  local isRuleMode = inputs.rules ~= nil

  local extraArgs = { '--update-all' }
  local bufrange, bufrange_err = utils.getBufrange(inputs.paths)
  if bufrange_err then
    params.on_finish('error', bufrange_err)
    return
  end
  if bufrange then
    inputs.paths = ''
    extraArgs = { '--update-all', '--stdin', '--lang=' .. search.get_language(bufrange.file_name) }
  end

  local args, blacklistedArgs =
    getArgs(inputs, params.options, extraArgs, blacklistedReplaceFlags, true)

  if blacklistedArgs and #blacklistedArgs > 0 then
    on_finish(nil, nil, 'replace cannot work with flags: ' .. table.concat(blacklistedArgs, ', '))
    return
  end

  if not args then
    on_finish(nil, nil, 'replace cannot work with the current arguments!')
    return
  end

  if not isRuleMode and #inputs.replacement == 0 then
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
      params.replacementInterpreter.get_eval_fn(inputs.replacement, { 'match', 'vars' })
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

  if bufrange then
    on_abort = replaceInBufrange({
      args = args,
      options = params.options,
      bufrange = bufrange,
      replacement_eval_fn = eval_fn,
      on_finish = on_finish,
    })
  elseif eval_fn then
    on_abort = replace_with_eval(params, args, eval_fn)
  else
    on_abort = fetchCommandOutput({
      cmd_path = params.options.engines.astgrep.path,
      args = args,
      on_fetch_chunk = function()
        -- astgrep does not report progress while replacing
      end,
      on_finish = on_finish,
    })
  end

  return abort
end

return M
