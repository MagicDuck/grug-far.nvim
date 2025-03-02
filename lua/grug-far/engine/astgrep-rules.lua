local search = require('grug-far.engine.astgrep.search')
local replace = require('grug-far.engine.astgrep.replace')

---@type GrugFarEngine
local AstgrepRulesEngine = {
  type = 'astgrep-rules',

  inputs = {
    {
      name = 'rules',
      label = 'Rules',
      iconName = 'searchInput',
      highlightLang = 'yaml',
      trim = false,
      getDefaultValue = function(context)
        local lang = ''
        if context.prevWin ~= nil then
          local bufId = vim.api.nvim_win_get_buf(context.prevWin)
          local filetype = vim.bo[bufId].filetype
          lang = filetype
        end

        local existingPattern = context.state.previousInputValues.search or ''

        return [[
id: my-rule-1
language: ]] .. lang .. '\n' .. [[
rule:
  pattern: ]] .. existingPattern
      end,
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

  getSearchDescription = function(inputs)
    return inputs.search
  end,

  isEmptySearch = function(inputs)
    return #inputs.rules == 0
  end,
}

return AstgrepRulesEngine
