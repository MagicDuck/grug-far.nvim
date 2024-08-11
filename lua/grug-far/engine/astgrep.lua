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

  search = search.search,

  replace = replace.replace,

  isSyncSupported = function()
    return false
  end,

  sync = function()
    -- not supported
  end,

  getInputPrefillsForVisualSelection = function(initialPrefills)
    local prefills = vim.deepcopy(initialPrefills)
    local selection_lines = utils.getVisualSelectionLines()
    prefills.search = vim.fn.join(selection_lines, '\n')
    return prefills
  end,
}

return AstgrepEngine
