local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')
local ProcessingQueue = require('grug-far/engine/ProcessingQueue')
local getRgVersion = require('grug-far/engine/ripgrep/getRgVersion')
local parseResults = require('grug-far/engine/ripgrep/parseResults')
local getArgs = require('grug-far/engine/ripgrep/getArgs')
local colors = require('grug-far/engine/ripgrep/colors')
local MatchReplacer = require('grug-far/engine/ripgrep/MatchReplacer')
local uv = vim.uv

local M = {}

--- get search args
---@param inputs GrugFarInputs
---@param options GrugFarOptions
---@return string[]?
function M.getSearchArgs(inputs, options)
  local extraArgs = { '--color=ansi' }
  for k, v in pairs(colors.rg_colors) do
    table.insert(extraArgs, '--colors=' .. k .. ':none')
    table.insert(extraArgs, '--colors=' .. k .. ':fg:' .. v.rgb)
  end

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
---@param params { data: string, matchReplacer: MatchReplacer, on_finish: fun(results: ParsedResultsData)}
local function getResultsWithReplaceDiff(params)
  local data = params.data
  params.matchReplacer:get_replaced_lines(data, function(replaced_lines)
    -- TODO (sbadragan): need to add diff bar sign
    local results = parseResults(data .. '\n' .. replaced_lines, false)
    params.on_finish(results)
  end)
end

---@param args string[]?
---@return string[]? newArgs
local function stripReplaceArgs(args)
  if not args then
    return nil
  end
  local newArgs = {}
  local stripNextArg = false
  for _, arg in ipairs(args) do
    local isOneArgReplace = vim.startswith(arg, '--replace=')
    local isTwoArgReplace = arg == '--replace' or arg == '-r'
    local stripArg = stripNextArg or isOneArgReplace or isTwoArgReplace
    stripNextArg = isTwoArgReplace

    if not stripArg then
      table.insert(newArgs, arg)
    end
  end

  return newArgs
end

--- does search
---@param params EngineSearchParams
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
  end

  local args = M.getSearchArgs(params.inputs, params.options)
  local isSearchWithReplace = M.isSearchWithReplacement(args)

  local on_fetch_chunk = function(data)
    params.on_fetch_chunk(parseResults(data, isSearchWithReplace))
  end

  local cleanup = nil
  local abort = nil
  local effectiveArgs = nil

  local showDiff = isSearchWithReplace and options.engines.ripgrep.showDiffOnReplace
  if showDiff then
    -- TODO (sbadragan): launch rg stdin process. If it fails for some reason, propagate the error
    args = stripReplaceArgs(args)

    local replaceInputs = vim.deepcopy(params.inputs)
    replaceInputs.paths = ''
    replaceInputs.filesFilter = ''
    local replaceArgs = M.getSearchArgs(replaceInputs, params.options) --[[ @as string[] ]]
    local processingQueue = nil
    local matchReplacer = MatchReplacer.new(params.options, replaceArgs, function(errorMessage)
      if processingQueue then
        processingQueue:stop()
      end
      if abort then
        abort()
      end
      params.on_finish('error', errorMessage)
    end)

    processingQueue = ProcessingQueue.new(function(data, on_done)
      getResultsWithReplaceDiff({
        data = data,
        matchReplacer = matchReplacer,
        on_finish = function(results)
          params.on_fetch_chunk(results)
          on_done()
        end,
      })
    end)

    on_fetch_chunk = function(data)
      processingQueue:push(data)
    end

    cleanup = function()
      processingQueue:stop()
      matchReplacer:destroy()
    end
  end

  abort, effectiveArgs = fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = args,
    on_fetch_chunk = on_fetch_chunk,
    on_finish = function(status, errorMessage)
      if cleanup then
        cleanup()
      end
      if status == 'error' and errorMessage and #errorMessage == 0 then
        errorMessage = 'no matches'
      end
      params.on_finish(status, errorMessage)
    end,
  })

  return abort, effectiveArgs
end

return M
