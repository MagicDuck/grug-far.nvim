local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')
local ProcessingQueue = require('grug-far/engine/ProcessingQueue')
local getRgVersion = require('grug-far/engine/ripgrep/getRgVersion')
local parseResults = require('grug-far/engine/ripgrep/parseResults')
local getArgs = require('grug-far/engine/ripgrep/getArgs')
local colors = require('grug-far/engine/ripgrep/colors')
local uv = vim.uv

local M = {}

--- get search args
---@param inputs GrugFarInputs
---@param options GrugFarOptions
---@return string[]?
-- TODO (sbadragan): update?
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

---@class ResultsWithReplaceDiffParams
-- TODO (sbadragan): fix this up
---@field json_data any
---@field options GrugFarOptions
---@field inputs GrugFarInputs
---@field on_finish fun(status: GrugFarStatus, errorMesage: string?, results: ParsedResultsData?)

--- adds results of doing a replace to results of doing a search
---@param params ResultsWithReplaceDiffParams
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
  local match_separator = '\029'

  local replaceInputs = vim.deepcopy(params.inputs)
  replaceInputs.paths = ''
  replaceInputs.filesFilter = ''
  local replaceArgs = getArgs(
    replaceInputs,
    params.options,
    { '--color=never', '--no-heading', '--no-line-number', '--no-column', '--no-filename' }
  ) --[[ @as string[] ]]

  local abort = fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = replaceArgs,
    stdin = stdin,
    on_fetch_chunk = function(data)
      replaced_matches_text = replaced_matches_text and replaced_matches_text .. data or data
    end,
    on_finish = function(status, errorMessage)
      -- TODO (sbadragan): on abort case handle
      if status == 'success' then
        ---@cast replaced_matches_text string
        local replaced_matches = vim.split(replaced_matches_text, match_separator)
        local i = 0
        for _, json_result in ipairs(json_data) do
          if json_result.type == 'match' then
            for _, submatch in ipairs(json_result.data.submatches) do
              i = i + 1
              submatch.replacement = { text = replaced_matches[i] }
            end
          end
        end

        -- TODO (sbadragan): need to parse those properly
        local results = parseResults('hello', false)
        params.on_finish(status, nil, results)
        P('gets here 1')
      else
        P('gets here 2')
        params.on_finish(status, errorMessage)
      end
    end,
  })

  uv.write(
    stdin,
    vim.fn.join(matches_for_replacement, match_separator) .. match_separator,
    function()
      uv.shutdown(stdin)
    end
  )
  print('run with', vim.inspect(matches_for_replacement))

  return abort
end

-- TODO (sbadragan): bug in history when not on lines
-- [C]: in function 'nvim_buf_get_lines'
-- /opt/repos/grug-far.nvim/lua/grug-far/utils.lua:251: in function 'ensureBufTopEmptyLines'
-- ...repos/grug-far.nvim/lua/grug-far/actions/historyOpen.lua:94: in function 'renderHistoryBuffer'
-- ...repos/grug-far.nvim/lua/grug-far/actions/historyOpen.lua:190: in function <...repos/grug-far.nvim/lua/grug-far/actions/historyOpen.lua:189>
--
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

---@class RipgrepEngineSearchParams
---@field args string[]?
---@field options GrugFarOptions
---@field inputs GrugFarInputs
---@field on_fetch_chunk fun(data: ParsedResultsData)
---@field on_finish fun(status: GrugFarStatus, errorMesage: string?, customActionMessage: string?)
---@field isSearchWithReplace boolean

--- runs search
---@param params RipgrepEngineSearchParams
---@return fun()? abort, string[]? effectiveArgs
local function run_search(params)
  return fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = params.args,
    on_fetch_chunk = function(data)
      params.on_fetch_chunk(parseResults(data, params.isSearchWithReplace))
    end,
    on_finish = function(status, errorMessage)
      if status == 'error' and errorMessage and #errorMessage == 0 then
        errorMessage = 'no matches'
      end
      params.on_finish(status, errorMessage)
    end,
  })
end

--- runs search with replace diff
---@param params RipgrepEngineSearchParams
---@return fun()? abort, string[]? effectiveArgs
local function run_search_with_replace_diff(params)
  local abortSearch = nil
  local effectiveArgs = nil
  local processingQueue = nil

  local abort = function()
    if processingQueue then
      processingQueue:stop()
    end
    if abortSearch then
      abortSearch()
    end
  end

  local searchArgs = stripReplaceArgs(params.args)
  if searchArgs then
    -- TODO (sbadragan): put this into getSearchArgs??
    table.insert(searchArgs, '--json')
  end

  processingQueue = ProcessingQueue.new(function(json_data, on_done)
    getResultsWithReplaceDiff({
      json_data = json_data,
      inputs = params.inputs,
      options = params.options,
      on_finish = function(status, errorMessage, results)
        if status == 'success' then
          if results then
            params.on_fetch_chunk(results)
          end
          on_done()
        else
          abort()
          P('finishing here 1')
          params.on_finish(status, errorMessage)
        end
      end,
    })
  end)

  abortSearch, effectiveArgs = fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = searchArgs,
    on_fetch_chunk = function(data)
      local json_lines = vim.split(data, '\n')
      local json_data = {}
      for _, json_line in ipairs(json_lines) do
        if #json_line > 0 then
          local entry = vim.json.decode(json_line)
          table.insert(json_data, entry)
        end
      end

      processingQueue:push(json_data)
    end,
    on_finish = function(status, errorMessage)
      if status == 'error' and errorMessage and #errorMessage == 0 then
        errorMessage = 'no matches'
      end
      if status == 'success' then
        processingQueue:on_finish(function()
          processingQueue:stop()
          P('finishing here 2')
          params.on_finish(status, errorMessage)
        end)
      else
        P('finishing here 2')
        processingQueue:stop()
        params.on_finish(status, errorMessage)
      end
    end,
  })

  return abort, effectiveArgs
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
  local showDiff = isSearchWithReplace and options.engines.ripgrep.showDiffOnReplace

  if showDiff then
    return run_search_with_replace_diff({
      options = options,
      inputs = params.inputs,
      args = args,
      on_fetch_chunk = params.on_fetch_chunk,
      on_finish = params.on_finish,
      isSearchWithReplace = isSearchWithReplace,
    })
  else
    return run_search({
      options = options,
      inputs = params.inputs,
      args = args,
      on_fetch_chunk = params.on_fetch_chunk,
      on_finish = params.on_finish,
      isSearchWithReplace = isSearchWithReplace,
    })
  end
end

return M
