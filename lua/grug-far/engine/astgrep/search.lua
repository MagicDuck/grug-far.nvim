local fetchCommandOutput = require('grug-far.engine.fetchCommandOutput')
local getArgs = require('grug-far.engine.astgrep.getArgs')
local parseResults = require('grug-far.engine.astgrep.parseResults')
local utils = require('grug-far.utils')
local blacklistedSearchFlags = require('grug-far.engine.astgrep.blacklistedSearchFlags')
local getAstgrepVersion = require('grug-far.engine.astgrep.getAstgrepVersion')
local argUtils = require('grug-far.engine.astgrep.argUtils')
local uv = vim.uv

local M = {}

--- gets search args
---@param inputs grug.far.Inputs
---@param options grug.far.Options
---@param extraArgs string[]?
---@return string[]?
function M.getSearchArgs(inputs, options, extraArgs)
  local _extraArgs = vim.deepcopy(extraArgs or {})
  table.insert(_extraArgs, '--json=stream')
  return getArgs(inputs, options, _extraArgs, blacklistedSearchFlags)
end

--- gets astgrep language for given filename
---@param file_name string
---@return string
function M.get_language(file_name)
  local ext = string.match(file_name, '^.+%.(.+)$')
  return ext
end

--- is doing a search with replacement?
---@param args string[]?
---@return boolean
function M.isSearchWithReplacement(args)
  if not args then
    return false
  end

  for i = 1, #args do
    if vim.startswith(args[i], '--rewrite=') or args[i] == '--rewrite' or args[i] == '-r' then
      return true
    end
  end

  return false
end

local textOutputFlags = { '-h', '--help', '--debug-query' }
--- is doing a non-json outputting command
---@param args string[]?
---@return boolean
local function isSearchWithTextOutput(args)
  if not args then
    return false
  end

  for _, flag in ipairs(args) do
    if utils.isBlacklistedFlag(flag, textOutputFlags) then
      return true
    end
  end

  return false
end

--- runs search
---@param args string[]?
---@param _bufrange? grug.far.VisualSelectionInfo
---@param options grug.far.Options
---@param eval_fn? fun(...): string
---@param on_fetch_chunk fun(data: grug.far.ParsedResultsData)
---@param on_finish fun(status: grug.far.Status, errorMessage: string?, customActionMessage: string?)
---@return fun()? abort, string[]? effectiveArgs
local function run_astgrep_search(args, _bufrange, options, eval_fn, on_fetch_chunk, on_finish)
  local isTextOutput = isSearchWithTextOutput(args)
  local bufrange = _bufrange and vim.deepcopy(_bufrange) or nil

  local matches = {}
  local chunk_error = nil
  local stdin = bufrange and uv.new_pipe() or nil
  local abort, effectiveArgs
  local partial_json_output = ''
  local hadNoResults = true
  abort, effectiveArgs = fetchCommandOutput({
    cmd_path = options.engines.astgrep.path,
    args = args,
    stdin = stdin,
    on_fetch_chunk = function(data)
      if chunk_error then
        return
      end
      if #data == 0 then
        return
      end
      if #partial_json_output > 0 then
        data = partial_json_output .. data
      end

      if isTextOutput then
        on_fetch_chunk({
          lines = vim.iter(vim.split(data, '\n')):map(utils.getLineWithoutCarriageReturn):totable(),
          highlights = {},
          marks = {},
          stats = { matches = 0, files = 0 },
        })
        return
      end

      local err = parseResults.json_decode_matches(matches, data, eval_fn)
      if err == '__json_decode_error__' then
        partial_json_output = data
        return
      end
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
      local results = parseResults.parseResults(before, bufrange, hadNoResults)
      if #results.lines > 0 then
        hadNoResults = false
      end
      on_fetch_chunk(results)
    end,
    on_finish = function(status, errorMessage)
      if chunk_error then
        status = 'error'
        errorMessage = chunk_error
      end
      if status == 'success' and #matches > 0 then
        -- do the last few
        local results = parseResults.parseResults(matches, bufrange, hadNoResults)
        if #results.lines > 0 then
          hadNoResults = false
        end
        on_fetch_chunk(results)
        matches = {}
      end
      vim.schedule(function()
        on_finish(status, errorMessage)
      end)
    end,
  })

  if stdin and bufrange then
    local text = table.concat(bufrange.lines, '\n')
    uv.write(stdin, text, function()
      uv.shutdown(stdin)
    end)
  end

  return abort, effectiveArgs
end

--- does search
---@param params grug.far.EngineSearchParams
---@param isRulesBasedSearch? boolean
---@return fun()? abort, string[]? effectiveArgs
function M.search(params, isRulesBasedSearch)
  local on_finish = params.on_finish
  local inputs = vim.deepcopy(params.inputs)

  local sg_version = getAstgrepVersion(params.options)
  if not sg_version then
    on_finish(
      'error',
      'ast-grep not found. Used command: '
        .. params.options.engines.astgrep.path
        .. '\nast-grep needs to be installed, see https://ast-grep.github.io'
    )
    return
  end
  local isRuleMode = inputs.rules ~= nil
  local numSearchChars = isRuleMode and #inputs.rules or #inputs.search
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

  local extraArgs = {}
  local bufrange, bufrange_err = utils.getBufrange(params.inputs.paths)
  if bufrange_err then
    params.on_finish('error', bufrange_err)
    return
  end
  if bufrange then
    inputs.paths = ''
    extraArgs = { '--stdin' }
    if not isRulesBasedSearch then
      table.insert(extraArgs, '--lang=' .. M.get_language(bufrange.file_name))
    end
  end

  local args, blacklistedArgs = M.getSearchArgs(inputs, params.options, extraArgs)

  if blacklistedArgs and #blacklistedArgs > 0 then
    on_finish(nil, nil, 'search cannot work with flags: ' .. table.concat(blacklistedArgs, ', '))
    return
  end

  if not args then
    on_finish(nil, nil, nil)
    return
  end

  local eval_fn
  if not isRuleMode and params.replacementInterpreter then
    local interpreterError
    eval_fn, interpreterError =
      params.replacementInterpreter.get_eval_fn(inputs.replacement, { 'match', 'vars' })
    if not eval_fn then
      on_finish('error', interpreterError)
      return
    end
    args = argUtils.stripReplaceArgs(args)
  end

  local hadOutput = false
  return run_astgrep_search(args, bufrange, params.options, eval_fn, function(data)
    if not hadOutput and #data.lines > 0 then
      hadOutput = true
    end
    params.on_fetch_chunk(data)
  end, function(status, errorMessage)
    -- give the user more feedback when there are no matches
    if status == 'success' and not (errorMessage and #errorMessage > 0) and not hadOutput then
      status = 'error'
      errorMessage = 'no matches'
    end

    on_finish(status, errorMessage)
  end)
end

return M
