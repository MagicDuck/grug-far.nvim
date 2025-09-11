local fetchCommandOutput = require('grug-far.engine.fetchCommandOutput')
local utils = require('grug-far.utils')
local ProcessingQueue = require('grug-far.engine.ProcessingQueue')
local getRgVersion = require('grug-far.engine.ripgrep.getRgVersion')
local parseResults = require('grug-far.engine.ripgrep.parseResults')
local getArgs = require('grug-far.engine.ripgrep.getArgs')
local argUtils = require('grug-far.engine.ripgrep.argUtils')
local uv = vim.uv

local M = {}

--- get search args
---@param inputs grug.far.Inputs
---@param options grug.far.Options
---@return string[]?
function M.getSearchArgs(inputs, options)
  local extraArgs = { '--json' }
  return getArgs(inputs, options, extraArgs)
end

--- is search with replace
---@param args string[]?
---@return boolean
function M.isSearchWithReplacement(args)
  if not args then
    return false
  end

  for i = 1, #args do
    if vim.startswith(args[i], '--replace=') or args[i] == '--replace' or args[i] == '-r' then
      return true
    end
  end

  return false
end

--- adds results of doing a replace to results of doing a search
---@param params {
--- json_data: RipgrepJson[],
--- options: grug.far.Options,
--- inputs: grug.far.Inputs,
--- bufrange: grug.far.VisualSelectionInfo,
--- on_finish: fun(status: grug.far.Status, errorMessage: string?, results: grug.far.ParsedResultsData?),
--- }
---@return fun()? abort
local function getResultsWithReplaceDiff(params)
  local json_data = params.json_data
  local matches_for_replacement = {}
  for _, json_result in ipairs(json_data) do
    if json_result.type == 'match' then
      for _, submatch in ipairs(json_result.data.submatches) do
        table.insert(matches_for_replacement, submatch.match.text)
      end
    end
  end
  if #matches_for_replacement == 0 then
    params.on_finish('success', nil, nil)
    return
  end

  local stdin = uv.new_pipe()
  local replaced_matches_text = nil
  local match_separator = '\0'

  local replaceInputs = vim.deepcopy(params.inputs)
  replaceInputs.paths = ''
  replaceInputs.filesFilter = ''
  local replaceArgs = getArgs(replaceInputs, params.options, {
    '--color=never',
    '--no-heading',
    '--no-line-number',
    '--no-column',
    '--no-filename',
    '--null-data',
  }) --[[ @as string[] ]]

  local inputString = ''
  for _, piece in ipairs(matches_for_replacement) do
    inputString = inputString .. piece .. match_separator
  end

  local bufrange = vim.deepcopy(params.bufrange)
  local hadNoResults = true
  local abort = fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = replaceArgs,
    stdin = stdin,
    fixChunkLineTruncation = false, -- NOTE: perf improvement
    on_fetch_chunk = function(data)
      replaced_matches_text = replaced_matches_text and replaced_matches_text .. data or data
    end,
    on_finish = function(status, errorMessage)
      if status == 'success' then
        ---@cast replaced_matches_text string
        local replaced_matches = vim.split(replaced_matches_text, match_separator)
        local i = 0
        for _, json_result in ipairs(json_data) do
          if json_result.type == 'match' then
            for _, submatch in ipairs(json_result.data.submatches) do
              i = i + 1
              submatch.replacement = { text = replaced_matches[i] or '' }
            end
          end
        end

        local showDiff = params.options.engines.ripgrep.showReplaceDiff
        local results = parseResults.parseResults(json_data, true, showDiff, bufrange, hadNoResults)
        if #results.lines > 0 then
          hadNoResults = false
        end

        params.on_finish(status, nil, results)
      else
        params.on_finish(status, errorMessage)
      end
    end,
  })

  uv.write(stdin, inputString, function()
    uv.shutdown(stdin)
  end)

  return abort
end

---@class grug.far.RipgrepEngineSearchParams
---@field stdin uv_pipe_t?
---@field args string[]?
---@field options grug.far.Options
---@field inputs grug.far.Inputs
---@field bufrange? grug.far.VisualSelectionInfo
---@field on_fetch_chunk fun(data: grug.far.ParsedResultsData)
---@field on_finish fun(status: grug.far.Status, errorMessage: string?, customActionMessage: string?)

--- runs search
---@param params grug.far.RipgrepEngineSearchParams
---@return fun()? abort, string[]? effectiveArgs
local function run_search(params)
  local bufrange = vim.deepcopy(params.bufrange)
  local matches = {}

  local hadNoResults = true
  return fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = params.args,
    stdin = params.stdin,
    on_fetch_chunk = function(data)
      if #data == 0 then
        return
      end

      -- handle non-json data (like when running rg with --help flag)
      if not vim.startswith(data, '{') then
        params.on_fetch_chunk({
          lines = vim.iter(vim.split(data, '\n')):map(utils.getLineWithoutCarriageReturn):totable(),
          highlights = {},
          marks = {},
          stats = { matches = 0, files = 0 },
        })
        return
      end

      -- note: we split off last file matches to ensure all matches for a file are processed at once.
      local json_list = utils.str_to_json_list(data)
      for _, match in ipairs(json_list) do
        table.insert(matches, match)
      end
      local before, after = parseResults.split_last_file_matches(matches)
      matches = after
      local results = parseResults.parseResults(before, false, false, bufrange, hadNoResults)
      params.on_fetch_chunk(results)
      if #results.lines > 0 then
        hadNoResults = false
      end
    end,
    on_finish = function(status, errorMessage)
      if status == 'error' and errorMessage and #errorMessage == 0 then
        errorMessage = 'no matches'
      end
      if status == 'success' and #matches > 0 then
        -- do the last few
        local results = parseResults.parseResults(matches, false, false, bufrange, hadNoResults)
        params.on_fetch_chunk(results)
        if #results.lines > 0 then
          hadNoResults = false
        end
        matches = {}
      end
      vim.schedule(function()
        params.on_finish(status, errorMessage)
      end)
    end,
  })
end

--- runs search with replace diff
---@param params grug.far.RipgrepEngineSearchParams
---@return fun()? abort, string[]? effectiveArgs
local function run_search_with_replace(params)
  local abortSearch = nil
  local effectiveArgs = nil
  local processingQueue = nil
  local has_finished = false
  local on_finish = function(...)
    if not has_finished then
      has_finished = true
      params.on_finish(...)
    end
  end
  local on_fetch_chunk = function(...)
    if not has_finished then
      params.on_fetch_chunk(...)
    end
  end

  local abort = function()
    if processingQueue then
      processingQueue:stop()
    end
    if abortSearch then
      abortSearch()
    end
    on_finish(nil, nil)
  end

  local searchArgs = argUtils.stripReplaceArgs(params.args)

  local matches = {}
  processingQueue = ProcessingQueue.new(function(data, on_done)
    if #data == 0 then
      on_done()
      return
    end

    -- handle non-json data (like when running rg with --help flag)
    if not vim.startswith(data, '{') then
      on_fetch_chunk({
        lines = vim.iter(vim.split(data, '\n')):map(utils.getLineWithoutCarriageReturn):totable(),
        highlights = {},
        marks = {},
        stats = { matches = 0, files = 0 },
      })
      on_done()
      return
    end

    local json_data = utils.str_to_json_list(data)
    for _, match in ipairs(json_data) do
      table.insert(matches, match)
    end
    local before, after = parseResults.split_last_file_matches(matches)
    matches = after

    getResultsWithReplaceDiff({
      json_data = before,
      inputs = params.inputs,
      options = params.options,
      bufrange = params.bufrange,
      on_finish = function(status, errorMessage, results)
        if status == 'success' then
          if results then
            on_fetch_chunk(results)
          end
          on_done()
          return
        else
          abort()
          on_finish(status, errorMessage)
        end
      end,
    })
  end)

  abortSearch, effectiveArgs = fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = searchArgs,
    stdin = params.stdin,
    on_fetch_chunk = function(data)
      processingQueue:push(data)
    end,
    on_finish = function(status, errorMessage)
      if status == 'error' and errorMessage and #errorMessage == 0 then
        errorMessage = 'no matches'
      end
      if status == 'success' then
        if #matches > 0 then
          -- do the last few
          processingQueue:push('{}')
        end
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

  return abort, effectiveArgs
end

--- runs search with replacement interpreter
---@param replacementInterpreter grug.far.ReplacementInterpreter
---@param params grug.far.RipgrepEngineSearchParams
---@return fun()? abort, string[]? effectiveArgs
local function run_search_with_replace_interpreter(replacementInterpreter, params)
  local eval_fn, interpreterError =
    replacementInterpreter.get_eval_fn(params.inputs.replacement, { 'match' })
  if not eval_fn then
    params.on_finish('error', interpreterError)
    return
  end

  local searchArgs = argUtils.stripReplaceArgs(params.args)
  local chunk_error = nil
  local abort, effectiveArgs
  local bufrange = vim.deepcopy(params.bufrange)
  local matches = {}
  local hadNoResults = true
  abort, effectiveArgs = fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = searchArgs,
    stdin = params.stdin,
    on_fetch_chunk = function(data)
      if chunk_error then
        return
      end
      if #data == 0 then
        return
      end

      -- handle non-json data (like when running rg with --help flag)
      if not vim.startswith(data, '{') then
        params.on_fetch_chunk({
          lines = vim.iter(vim.split(data, '\n')):map(utils.getLineWithoutCarriageReturn):totable(),
          highlights = {},
          marks = {},
          stats = { matches = 0, files = 0 },
        })
        return
      end

      local json_list = utils.str_to_json_list(data)
      for _, entry in ipairs(json_list) do
        if entry.type == 'match' then
          for _, submatch in ipairs(entry.data.submatches) do
            ---@cast eval_fn fun(...): string
            local replacementText, err = eval_fn(submatch.match.text)
            if err then
              chunk_error = err
              if abort then
                abort()
              end
              return
            end
            submatch.replacement = { text = replacementText }
          end
        end
      end

      for _, match in ipairs(json_list) do
        table.insert(matches, match)
      end
      local before, after = parseResults.split_last_file_matches(matches)
      matches = after
      local results = parseResults.parseResults(before, true, true, bufrange, hadNoResults)
      params.on_fetch_chunk(results)
      if #results.lines > 0 then
        hadNoResults = false
      end
    end,
    on_finish = function(status, errorMessage)
      if status == 'error' and errorMessage and #errorMessage == 0 then
        errorMessage = 'no matches'
      end
      if chunk_error then
        status = 'error'
        errorMessage = chunk_error
      end
      if status == 'success' and #matches > 0 then
        -- do the last few
        local results = parseResults.parseResults(matches, true, true, bufrange, hadNoResults)
        params.on_fetch_chunk(results)
        if #results.lines > 0 then
          hadNoResults = false
        end
        matches = {}
      end
      vim.schedule(function()
        params.on_finish(status, errorMessage)
      end)
    end,
  })

  return abort, effectiveArgs
end

--- does search
---@param params grug.far.EngineSearchParams
---@return fun()? abort, string[]? effectiveArgs
function M.search(params)
  local options = params.options
  local version = getRgVersion(options)
  if not version then
    params.on_finish(
      'error',
      'ripgrep not found. Used command: '
        .. params.options.engines.ripgrep.path
        .. '\nripgrep needs to be installed, see https://github.com/BurntSushi/ripgrep'
    )
    return
  end
  local numSearchChars = #params.inputs.search
  if numSearchChars > 0 and numSearchChars < (params.options.minSearchChars or 1) then
    params.on_finish(
      'success',
      nil,
      'Please enter at least '
        .. params.options.minSearchChars
        .. ' search chars to trigger search!'
    )
    return
  end

  local bufrange, bufrange_err = utils.getBufrange(params.inputs.paths)
  if bufrange_err then
    params.on_finish('error', bufrange_err)
    return
  end

  local inputs = vim.deepcopy(params.inputs)
  if bufrange then
    inputs.paths = ''
  end
  local args = M.getSearchArgs(inputs, params.options)
  local isSearchWithReplace = M.isSearchWithReplacement(args)
  local stdin = bufrange and uv.new_pipe() or nil

  local abort, effectiveArgs
  if params.replacementInterpreter then
    abort, effectiveArgs = run_search_with_replace_interpreter(params.replacementInterpreter, {
      stdin = stdin,
      options = options,
      inputs = inputs,
      bufrange = bufrange,
      args = args,
      on_fetch_chunk = params.on_fetch_chunk,
      on_finish = params.on_finish,
    })
  elseif isSearchWithReplace then
    abort, effectiveArgs = run_search_with_replace({
      stdin = stdin,
      options = options,
      inputs = inputs,
      bufrange = bufrange,
      args = args,
      on_fetch_chunk = params.on_fetch_chunk,
      on_finish = params.on_finish,
    })
  else
    abort, effectiveArgs = run_search({
      stdin = stdin,
      options = options,
      inputs = inputs,
      bufrange = bufrange,
      args = args,
      on_fetch_chunk = params.on_fetch_chunk,
      on_finish = params.on_finish,
    })
  end

  if stdin and bufrange then
    -- note: ripgrep parsing expects a trailing newline
    local text = table.concat(bufrange.lines, utils.eol) .. utils.eol
    uv.write(stdin, text, function()
      uv.shutdown(stdin)
    end)
  end

  return abort, effectiveArgs
end

return M
