local fetchFilesWithMatches = require('grug-far/engine/ripgrep/fetchFilesWithMatches')
local replaceInMatchedFiles = require('grug-far/engine/ripgrep/replaceInMatchedFiles')
local syncChangedFiles = require('grug-far/engine/syncChangedFiles')
local getArgs = require('grug-far/engine/ripgrep/getArgs')
local search = require('grug-far/engine/ripgrep/search')
local utils = require('grug-far/utils')

--- are we replacing matches with the empty string?
---@param args string[]
---@return boolean
local function isEmptyStringReplace(args)
  local replaceEqArg = '--replace='
  for i = #args, 1, -1 do
    local arg = args[i]
    if vim.startswith(arg, replaceEqArg) then
      if #arg > #replaceEqArg then
        return false
      else
        return true
      end
    end
  end

  return true
end

--- are we doing a multiline search and replace?
---@param args string[]
---@return boolean
local function isMultilineSearchReplace(args)
  local multilineFlags = { '--multiline', '-U', '--multiline-dotall' }
  for _, arg in ipairs(args) do
    if utils.isBlacklistedFlag(arg, multilineFlags) then
      return true
    end
  end

  return false
end

---@type GrugFarEngine
local RipgrepEngine = {
  type = 'ripgrep',

  isSearchWithReplacement = function(inputs, options)
    local args = search.getSearchArgs(inputs, options)
    return search.isSearchWithReplacement(args)
  end,

  search = search.search,

  replace = function(params)
    local report_progress = params.report_progress
    local on_finish = params.on_finish

    local args = getArgs(params.inputs, params.options, {})
    if not args then
      on_finish(nil, nil, 'replace cannot work with the current arguments!')
      return
    end

    if isEmptyStringReplace(args) then
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

    on_abort = fetchFilesWithMatches({
      inputs = params.inputs,
      options = params.options,
      report_progress = function(count)
        report_progress({ type = 'update_total', count = count })
      end,
      on_finish = function(status, errorMessage, files, blacklistedArgs)
        if not status then
          on_finish(
            nil,
            nil,
            blacklistedArgs
                and 'replace cannot work with flags: ' .. vim.fn.join(blacklistedArgs, ', ')
              or nil
          )
          return
        elseif status == 'error' then
          on_finish(status, errorMessage)
          return
        end

        on_abort = replaceInMatchedFiles({
          files = files,
          inputs = params.inputs,
          options = params.options,
          report_progress = function(count)
            report_progress({ type = 'update_count', count = count })
          end,
          on_finish = on_finish,
        })
      end,
    })

    return abort
  end,

  isSyncSupported = function()
    return true
  end,

  sync = function(params)
    local on_finish = params.on_finish

    local args = getArgs(params.inputs, params.options, {})
    if not args then
      on_finish(nil, nil, 'sync cannot work with the current arguments!')
      return
    end

    if isMultilineSearchReplace(args) then
      on_finish(nil, nil, 'sync disabled for multline search/replace!')
      return
    end

    return syncChangedFiles({
      options = params.options,
      report_progress = function(count)
        params.report_progress({ type = 'update_count', count = count })
      end,
      on_finish = params.on_finish,
      changedFiles = params.changedFiles,
    })
  end,

  getInputPrefillsForVisualSelection = function(initialPrefills)
    local prefills = vim.deepcopy(initialPrefills)

    local selection_lines = utils.getVisualSelectionLines()
    prefills.search = vim.fn.join(selection_lines, '\n')
    local flags = prefills.flags or ''
    if not flags:find('%-%-fixed%-strings') then
      flags = (#flags > 0 and flags .. ' ' or flags) .. '--fixed-strings'
    end
    if #selection_lines > 1 and not flags:find('%-%-multiline') then
      flags = (#flags > 0 and flags .. ' ' or flags) .. '--multiline'
    end
    prefills.flags = flags

    return prefills
  end,
}

return RipgrepEngine
