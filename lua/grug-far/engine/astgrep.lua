local search = require('grug-far.engine.astgrep.search')
local replace = require('grug-far.engine.astgrep.replace')

---@type GrugFarEngine
local AstgrepEngine = {
  type = 'astgrep',

  inputs = {
    {
      name = 'search',
      label = 'Search',
      iconName = 'searchInput',
      highlightLang = 'regex',
      trim = false,
    },
    {
      name = 'replacement',
      label = 'Replace',
      iconName = 'replaceInput',
      highlightLang = nil,
      trim = false,
    },
    {
      name = 'filesFilter',
      label = 'Files Filter',
      iconName = 'filesFilterInput',
      highlightLang = 'gitignore',
      trim = true,
    },
    {
      name = 'flags',
      label = 'Flags',
      iconName = 'flagsInput',
      highlightLang = 'bash',
      trim = true,
    },
    {
      name = 'paths',
      label = 'Paths',
      iconName = 'pathsInput',
      highlightLang = 'bash',
      trim = true,
    },
  },

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
    prefills.search = table.concat(visual_selection, '\n')
    return prefills
  end,
}

return AstgrepEngine
