local search = require('grug-far.engine.ripgrep.search')
local replace = require('grug-far.engine.ripgrep.replace')
local sync = require('grug-far.engine.ripgrep.sync')
local utils = require('grug-far.utils')

---@type grug.far.Engine
local RipgrepEngine = {
  type = 'ripgrep',

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
      replacementInterpreterEnabled = true,
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

  bufrangeInputName = 'paths',

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

  getInputPrefillsForVisualSelection = function(
    visual_selection_info,
    initialPrefills,
    visualSelectionUsage
  )
    local prefills = vim.deepcopy(initialPrefills)

    if visualSelectionUsage == 'prefill-search' then
      prefills.search = table.concat(visual_selection_info.lines, '\n')
      local flags = prefills.flags or ''
      if not flags:find('%-%-fixed%-strings') then
        flags = (#flags > 0 and flags .. ' ' or flags) .. '--fixed-strings'
      end
      if #visual_selection_info.lines > 1 and not flags:find('%-%-multiline') then
        flags = (#flags > 0 and flags .. ' ' or flags) .. '--multiline'
      end
      prefills.flags = flags
    elseif visualSelectionUsage == 'operate-within-range' then
      prefills.paths = utils.get_visual_selection_info_as_str(visual_selection_info)
    end

    return prefills
  end,

  getSearchDescription = function(inputs)
    return inputs.search
  end,

  isEmptySearch = function(inputs)
    return #inputs.search == 0
  end,
}

return RipgrepEngine
