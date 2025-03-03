local search = require('grug-far.engine.astgrep.search')
local replace = require('grug-far.engine.astgrep.replace')

local function matches_glob(filename, glob)
  local pattern = vim.fn.glob2regpat(glob)
  if vim.fn.match(filename, pattern) ~= -1 then
    return true
  end
  return false
end

---@return string | nil
local function get_language_by_glob(filename, languageGlobs)
  for lang, globs in pairs(languageGlobs) do
    for _, glob in ipairs(globs) do
      if matches_glob(filename, glob) then
        return lang
      end
    end
  end
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
        if context.prevBufFiletype ~= nil then
          lang = context.prevBufFiletype
        end
        if context.prevBufName ~= nil then
          local byGlob = get_language_by_glob(
            context.prevBufName,
            context.options.engines['astgrep-rules'].languageGlobs
          )
          if byGlob ~= nil then
            lang = byGlob
          end
        end

        local existingPattern = context.state.previousInputValues.search or ''

        local defaultValue = [[
id: my_rule_1
language: ]] .. lang .. '\n' .. [[
rule:
  pattern: ]] .. existingPattern

        local existingReplacement = context.state.previousInputValues.replacement
        if #existingReplacement > 0 then
          defaultValue = (defaultValue .. '\nfix: ' .. existingReplacement)
        end

        return defaultValue
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
    return inputs.rules
  end,

  isEmptySearch = function(inputs)
    return #inputs.rules == 0
  end,
}

return AstgrepRulesEngine
