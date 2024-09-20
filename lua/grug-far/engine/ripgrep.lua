local search = require('grug-far/engine/ripgrep/search')
local replace = require('grug-far/engine/ripgrep/replace')
local sync = require('grug-far/engine/ripgrep/sync')
local utils = require('grug-far/utils')

---@type GrugFarEngine
local RipgrepEngine = {
  type = 'ripgrep',

  isSearchWithReplacement = function(inputs, options)
    local args = search.getSearchArgs(inputs, options)
    return search.isSearchWithReplacement(args)
  end,

  showsReplaceDiff = function(options)
    return options.engines.ripgrep.showReplaceDiff
  end,

  search = search.search,

  replace = replace.replace,

  isSyncSupported = function()
    return true
  end,

  sync = sync.sync,

  getInputPrefillsForVisualSelection = function(visual_selection, initialPrefills)
    local prefills = vim.deepcopy(initialPrefills)

    prefills.search = vim.fn.join(visual_selection, '\n')
    local flags = prefills.flags or ''
    if not flags:find('%-%-fixed%-strings') then
      flags = (#flags > 0 and flags .. ' ' or flags) .. '--fixed-strings'
    end
    if #visual_selection > 1 and not flags:find('%-%-multiline') then
      flags = (#flags > 0 and flags .. ' ' or flags) .. '--multiline'
    end
    prefills.flags = flags

    return prefills
  end,
}

return RipgrepEngine
