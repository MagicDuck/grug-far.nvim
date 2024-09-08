local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')
local getRgVersion = require('grug-far/engine/ripgrep/getRgVersion')
local parseResults = require('grug-far/engine/ripgrep/parseResults')
local getArgs = require('grug-far/engine/ripgrep/getArgs')
local colors = require('grug-far/engine/ripgrep/colors')

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

  local showDiff = isSearchWithReplace and options.engines.ripgrep.showDiffOnReplace
  if showDiff then
    args = stripReplaceArgs(args)

    local results_to_process = {}
    local processNext = function()
      local results = results_to_process[1]
      -- TODO (sbadragan): do the thing
      getReplacementResults(results, function(replacementResults)
        local mergedResults = results + replacementResults
        params.on_fetch_chunk(mergedResults)
        table.remove(results_to_process, 1)
        if #results_to_process > 0 then
          processNext()
        end
      end)
    end

    on_fetch_chunk = function(data)
      local results = parseResults(data, false)
      table.insert(results_to_process, results)

      if #results_to_process == 1 then
        procesNext()
      end

      -- if showDiff then
      --   params.on_fetch_chunk(results)
      -- else
      --   params.on_fetch_chunk(parseResults(data, isSearchWithReplace))
      -- end
    end
  end

  return fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = args,
    options = params.options,
    on_fetch_chunk = on_fetch_chunk,
    on_finish = function(status, errorMessage)
      if status == 'error' and errorMessage and #errorMessage == 0 then
        errorMessage = 'no matches'
      end
      params.on_finish(status, errorMessage)
    end,
  })
end

return M
