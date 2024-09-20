local utils = require('grug-far/utils')
local search = require('grug-far/engine/astgrep/search')
local replace = require('grug-far/engine/astgrep/replace')

---@type GrugFarEngine
local AstgrepEngine = {
  type = 'astgrep',

  isSearchWithReplacement = function(inputs, options)
    local args = search.getSearchArgs(inputs, options)
    return search.isSearchWithReplacement(args)
  end,

  showsReplaceDiff = function()
    return true
  end,

  search = search.search,

  replace = replace.replace,

  isSyncSupported = function()
    return false
  end,

  sync = function()
    -- not supported
  end,

  getInputPrefillsForVisualSelection = function(visual_selection, initialPrefills)
    local prefills = vim.deepcopy(initialPrefills)
    prefills.search = vim.fn.join(visual_selection, '\n')
    return prefills
  end,
}

return AstgrepEngine
