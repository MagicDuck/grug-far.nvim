local search = require('grug-far.engine.astgrep.search')
local replace = require('grug-far.engine.astgrep.replace')

---@type GrugFarEngine
local AstgrepEngine = {
  type = 'astgreprule',

  isSearchWithReplacement = function(inputs, options)
    local args = search.getSearchArgs(inputs, options, true)
    return search.isSearchWithReplacement(args)
  end,

  showsReplaceDiff = function()
    return true
  end,

  search = function(params)
    return search.search(params, true)
  end,

  replace = function(params)
    return replace.replace(params, true)
  end,

  isSyncSupported = function()
    return false
  end,

  sync = function()
    -- not supported
  end,

  getInputPrefillsForVisualSelection = function(visual_selection, initialPrefills)
    local prefills = vim.deepcopy(initialPrefills)
    prefills.search = table.concat(visual_selection, '\n')
    return prefills
  end,
}

return AstgrepEngine
