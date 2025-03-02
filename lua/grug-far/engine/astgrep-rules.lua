local search = require('grug-far.engine.astgrep.search')
local replace = require('grug-far.engine.astgrep.replace')

local function matches_glob(filename, glob)
  local pattern = vim.fn.glob2regpat(glob)
  if vim.fn.match(filename, pattern) ~= -1 then
    return true
  end
  return false
end

local function get_language_by_glob(filename, languageGlobs)
  for lang, globs in pairs(languageGlobs) do
    for _, glob in ipairs(globs) do
      if matches_glob(filename, glob) then
        return lang
      end
    end
  end
end

local function shallow_copy(tbl)
  local copy = {}
  for k, v in pairs(tbl) do
    copy[k] = v
  end
  return copy
end

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

          local filename = vim.api.nvim_buf_get_name(bufId)
          lang = get_language_by_glob(
            filename,
            context.options.engines['astgrep-rules'].languageGlobs
          ) or lang
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

  isSearchWithReplacement = function(i, options)
    local inputs = shallow_copy(i)
    inputs.isRuleMode = true
    local args = search.getSearchArgs(inputs, options)
    return search.isSearchWithReplacement(args)
  end,

  showsReplaceDiff = function()
    return true
  end,

  search = function(p)
    local params = shallow_copy(p)
    p.inputs = shallow_copy(params.inputs)
    params.inputs.isRuleMode = true
    search.search(params)
  end,

  replace = function(p)
    local params = shallow_copy(p)
    p.inputs = shallow_copy(params.inputs)
    params.inputs.isRuleMode = true
    replace.replace(params)
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

  getSearchDescription = function(inputs)
    return inputs.rules
  end,

  isEmptySearch = function(inputs)
    return #inputs.rules == 0
  end,
}

return AstgrepRulesEngine
