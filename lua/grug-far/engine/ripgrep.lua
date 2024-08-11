local syncChangedFiles = require('grug-far/engine/syncChangedFiles')
local getArgs = require('grug-far/engine/ripgrep/getArgs')
local search = require('grug-far/engine/ripgrep/search')
local replace = require('grug-far/engine/ripgrep/replace')
local utils = require('grug-far/utils')

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

  replace = replace.replace,

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
