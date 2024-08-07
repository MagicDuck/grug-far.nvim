local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')
local getArgs = require('grug-far/engine/astgrep/getArgs')
local parseResults = require('grug-far/engine/astgrep/parseResults')
local utils = require('grug-far/utils')
local blacklistedSearchFlags = require('grug-far/engine/astgrep/blacklistedSearchFlags')
local blacklistedReplaceFlags = require('grug-far/engine/astgrep/blacklistedReplaceFlags')
local getAstgrepVersion = require('grug-far/engine/astgrep/getAstgrepVersion')
local fetchFilteredFilesList = require('grug-far/engine/ripgrep/fetchFilteredFilesList')
local runWithChunkedFiles = require('grug-far/engine/runWithChunkedFiles')
local getRgVersion = require('grug-far/engine/ripgrep/getRgVersion')

--- decodes streamed json matches, appending to given table
---@param matches AstgrepMatch[]
---@param data string
local function json_decode_matches(matches, data)
  local json_lines = vim.split(data, '\n')
  for _, json_line in ipairs(json_lines) do
    if #json_line > 0 then
      local match = vim.json.decode(json_line)
      table.insert(matches, match)
    end
  end
end

--- splits off matches corresponding to the last file
---@param matches AstgrepMatch[]
---@return AstgrepMatch[] before, AstgrepMatch[] after
local function split_last_file_matches(matches)
  local end_index = 0
  for i = #matches - 1, 1, -1 do
    if matches[i].file ~= matches[i + 1].file then
      end_index = i
      break
    end
  end

  local before = {}
  for i = 1, end_index do
    table.insert(before, matches[i])
  end
  local after = {}
  for i = end_index + 1, #matches do
    table.insert(after, matches[i])
  end

  return before, after
end

--- gets search args
---@param inputs GrugFarInputs
---@param options GrugFarOptions
---@return string[]?
local function getSearchArgs(inputs, options)
  local extraArgs = {
    '--json=stream',
  }
  return getArgs(inputs, options, extraArgs, blacklistedSearchFlags)
end

--- is doing a search with replacement?
---@param args string[]?
---@return boolean
local function isSearchWithReplacement(args)
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
---@param on_fetch_chunk fun(data: ParsedResultsData)
---@param on_finish fun(status: GrugFarStatus, errorMessage: string?, customActionMessage: string?)
---@return fun()? abort
local function run_search(args, options, on_fetch_chunk, on_finish)
  local isTextOutput = isSearchWithTextOutput(args)

  local matches = {}
  return fetchCommandOutput({
    cmd_path = options.engines.astgrep.path,
    args = args,
    options = options,
    on_fetch_chunk = function(data)
      if isTextOutput then
        on_fetch_chunk({
          lines = vim.iter(vim.split(data, '\n')):map(utils.getLineWithoutCarriageReturn):totable(),
          highlights = {},
          stats = { matches = 0, files = 0 },
        })
        return
      end

      json_decode_matches(matches, data)
      -- note: we split off last file matches to ensure all matches for a file are processed
      -- at once. This helps with applying replacements
      local before, after = split_last_file_matches(matches)
      matches = after
      on_fetch_chunk(parseResults(before))
    end,
    on_finish = function(status, errorMessage)
      if #matches > 0 then
        -- do the last few
        on_fetch_chunk(parseResults(matches))
        matches = {}
      end
      on_finish(status, errorMessage)
    end,
  })
end

---@type GrugFarEngine
local AstgrepEngine = {
  type = 'astgrep',

  isSearchWithReplacement = function(inputs, options)
    local args = getSearchArgs(inputs, options)
    return isSearchWithReplacement(args)
  end,

  search = function(params)
    local on_finish = params.on_finish
    local sg_version = getAstgrepVersion(params.options)
    if not sg_version then
      on_finish(
        'error',
        'ast-grep not found. Used command: '
          .. params.options.engines.astgrep.path
          .. '\nast-grep needs to be installed, see https://ast-grep.github.io'
      )
    end

    local rg_version = getRgVersion(params.options)
    if not rg_version then
      on_finish(
        'error',
        'ripgrep not found. Used command: '
          .. params.options.engines.ripgrep.path
          .. '\nripgrep needs to be installed, see https://github.com/BurntSushi/ripgrep'
      )
    end

    local args, blacklistedArgs = getSearchArgs(params.inputs, params.options)

    if blacklistedArgs and #blacklistedArgs > 0 then
      on_finish(nil, nil, 'search cannot work with flags: ' .. vim.fn.join(blacklistedArgs, ', '))
      return
    end

    if not args then
      on_finish(nil, nil, nil)
      return
    end

    local hadOutput = false
    local filesFilter = params.inputs.filesFilter
    if filesFilter and #filesFilter > 0 then
      -- ast-grep currently does not support --glob type functionality
      -- see see https://github.com/ast-grep/ast-grep/issues/1062
      -- this if-branch uses rg to get the files and can be removed if that is implemented

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

              return run_search(chunk_args, params.options, function(data)
                hadOutput = true
                params.on_fetch_chunk(data)
              end, function(_, _errorMessage)
                return on_done((_errorMessage and #_errorMessage > 0) and _errorMessage or nil)
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

      return abort
    else
      return run_search(args, params.options, function(data)
        hadOutput = true
        params.on_fetch_chunk(data)
      end, function(_status, _errorMessage)
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
      end)
    end
  end,

  replace = function(params)
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

    local on_abort = nil
    local function abort()
      if on_abort then
        on_abort()
      end
    end

    report_progress({
      type = 'message',
      message = 'replacing... (buffer temporarily not modifiable)',
    })

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

              return fetchCommandOutput({
                cmd_path = params.options.engines.astgrep.path,
                args = chunk_args,
                options = params.options,
                on_fetch_chunk = function()
                  -- astgrep does not report progess while replacing
                end,
                on_finish = function(_, _errorMessage)
                  return on_done((_errorMessage and #_errorMessage > 0) and _errorMessage or nil)
                end,
              })
            end,
            on_finish = on_finish,
          })
        end,
      })
    else
      on_abort = fetchCommandOutput({
        cmd_path = params.options.engines.astgrep.path,
        args = args,
        options = params.options,
        on_fetch_chunk = function()
          -- astgrep does not report progess while replacing
        end,
        on_finish = on_finish,
      })
    end

    return abort
  end,

  isSyncSupported = function()
    return false
  end,

  sync = function()
    -- not supported
  end,

  getInputPrefillsForVisualSelection = function(initialPrefills)
    local prefills = vim.deepcopy(initialPrefills)
    prefills.search = utils.getVisualSelectionText()
    return prefills
  end,
}

return AstgrepEngine
