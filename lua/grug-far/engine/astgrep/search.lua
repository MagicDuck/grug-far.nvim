local fetchCommandOutput = require('grug-far.engine.fetchCommandOutput')
local getArgs = require('grug-far.engine.astgrep.getArgs')
local parseResults = require('grug-far.engine.astgrep.parseResults')
local utils = require('grug-far.utils')
local blacklistedSearchFlags = require('grug-far.engine.astgrep.blacklistedSearchFlags')
local getAstgrepVersion = require('grug-far.engine.astgrep.getAstgrepVersion')
local fetchFilteredFilesList = require('grug-far.engine.ripgrep.fetchFilteredFilesList')
local runWithChunkedFiles = require('grug-far.engine.runWithChunkedFiles')
local getRgVersion = require('grug-far.engine.ripgrep.getRgVersion')
local argUtils = require('grug-far.engine.astgrep.argUtils')

local M = {}

--- gets search args
---@param inputs GrugFarInputs
---@param options GrugFarOptions
---@return string[]?
function M.getSearchArgs(inputs, options)
  local extraArgs = {
    '--json=stream',
  }
  return getArgs(inputs, options, extraArgs, blacklistedSearchFlags)
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
---@param options GrugFarOptions
---@param eval_fn? fun(...): string
---@param on_fetch_chunk fun(data: ParsedResultsData)
---@param on_finish fun(status: GrugFarStatus, errorMessage: string?, customActionMessage: string?)
---@return fun()? abort, string[]? effectiveArgs
local function run_astgrep_search(args, options, eval_fn, on_fetch_chunk, on_finish)
  local isTextOutput = isSearchWithTextOutput(args)

  local matches = {}
  local chunk_error = nil
  local abort, effectiveArgs
  abort, effectiveArgs = fetchCommandOutput({
    cmd_path = options.engines.astgrep.path,
    args = args,
    on_fetch_chunk = function(data)
      if chunk_error then
        return
      end

      if isTextOutput then
        on_fetch_chunk({
          lines = vim.iter(vim.split(data, '\n')):map(utils.getLineWithoutCarriageReturn):totable(),
          highlights = {},
          stats = { matches = 0, files = 0 },
        })
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
      on_fetch_chunk(parseResults.parseResults(before))
    end,
    on_finish = function(status, errorMessage)
      if chunk_error then
        status = 'error'
        errorMessage = chunk_error
      end
      if status == 'success' and #matches > 0 then
        -- do the last few
        on_fetch_chunk(parseResults.parseResults(matches))
        matches = {}
      end
      vim.schedule(function()
        on_finish(status, errorMessage)
      end)
    end,
  })

  return abort, effectiveArgs
end

--- does search
---@param params EngineSearchParams
---@return fun()? abort, string[]? effectiveArgs
function M.search(params)
  local on_finish = params.on_finish
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

  local rg_version = getRgVersion(params.options)
  if not rg_version then
    on_finish(
      'error',
      'ripgrep not found. Used command: '
        .. params.options.engines.ripgrep.path
        .. '\nripgrep needs to be installed, see https://github.com/BurntSushi/ripgrep'
    )
    return
  end

  local args, blacklistedArgs = M.getSearchArgs(params.inputs, params.options)

  if blacklistedArgs and #blacklistedArgs > 0 then
    on_finish(nil, nil, 'search cannot work with flags: ' .. vim.fn.join(blacklistedArgs, ', '))
    return
  end

  if not args then
    on_finish(nil, nil, nil)
    return
  end

  local eval_fn
  if params.replacementInterpreter then
    local interpreterError
    eval_fn, interpreterError =
      params.replacementInterpreter.get_eval_fn(params.inputs.replacement, { 'match', 'vars' })
    if not eval_fn then
      on_finish('error', interpreterError)
      return
    end
    args = argUtils.stripReplaceArgs(args)
  end

  local hadOutput = false
  local filesFilter = params.inputs.filesFilter
  local version = getAstgrepVersion(params.options)
  if filesFilter and #filesFilter > 0 and version and vim.version.gt(version, '0.28.0') then
    -- note: astgrep added --glob suport in v0.28.0
    -- this if-branch uses rg to get the files and can be removed in the future once everybody uses new astgrep

    local on_abort = nil
    local function abort()
      if on_abort then
        on_abort()
      end
    end

    on_abort = fetchFilteredFilesList({
      inputs = params.inputs,
      options = params.options,
      report_progress = function() end,
      on_finish = function(status, errorMessage, files)
        on_abort = nil
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

            return run_astgrep_search(chunk_args, params.options, eval_fn, function(data)
              if not hadOutput and #data.lines > 0 then
                hadOutput = true
              end
              params.on_fetch_chunk(data)
            end, function(_status, _errorMessage)
              if _status == 'error' then
                local err = (_errorMessage and #_errorMessage > 0) and _errorMessage
                  or 'Unexpected Error!'
                return on_done(err)
              end
              return on_done(nil)
            end)
          end,
          on_finish = function(_status, _errorMessage)
            -- give the user more feedback when there are no matches
            if
              _status == 'success'
              and not (_errorMessage and #_errorMessage > 0)
              and not hadOutput
            then
              _status = 'error'
              _errorMessage = 'no matches'
            end

            on_finish(_status, _errorMessage)
          end,
        })
      end,
    })

    return abort, args
  else
    return run_astgrep_search(args, params.options, eval_fn, function(data)
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
end

return M
