local search = require('grug-far.engine.astgrep.search')
local replace = require('grug-far.engine.astgrep.replace')
local utils = require('grug-far.utils')

---@param filename string
---@param glob string
local function matches_glob(filename, glob)
  local pattern = vim.fn.glob2regpat(glob)
  if vim.fn.match(filename, pattern) ~= -1 then
    return true
  end
  return false
end

---@param filename string
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

---@param context grug.far.Context
---@return string | nil
local function get_default_astgrep_language(context)
  local lang = nil

  -- Filetype of the recently opened buffer is a reasonable guess
  if context.prevBufFiletype ~= nil then
    lang = context.prevBufFiletype
  end

  -- If the user has configure any globs to map filenames to languages, we can
  -- use those
  if context.prevBufName ~= nil then
    local byGlob = get_language_by_glob(
      context.prevBufName,
      context.options.engines['astgrep-rules'].languageGlobs
    )
    if byGlob ~= nil then
      lang = byGlob
    end
  end

  return lang
end

---@type grug.far.Engine
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
        local existingValue = context.state.previousInputValues.rules or ''
        if #existingValue > 0 then
          return existingValue
        end

        -- If the user was already working on search and replace patterns with
        -- the astgrep engine, those can be injected into the YAML as a good
        -- starting point
        local existingPattern = context.state.previousInputValues.search or ''
        local existingReplacement = context.state.previousInputValues.replacement or ''

        -- a `language` field is compulsory. For convenience, we can try to
        -- guess what the user willl want
        local lang = get_default_astgrep_language(context) or ''

        local defaultValue = [[
id: my_rule_1
language: ]] .. lang .. '\n' .. [[
rule:
  pattern: ]] .. existingPattern

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

  search = function(...)
    search.search(..., true)
  end,

  replace = function(...)
    replace.replace(..., true)
  end,

  isSyncSupported = function()
    return false
  end,

  sync = function()
    -- not supported
  end,

  getInputPrefillsForVisualSelection = function(
    visual_selection_info,
    initialPrefills,
    visualSelectionUsage
  )
    local prefills = vim.deepcopy(initialPrefills)
    if visualSelectionUsage == 'prefill-search' then
      prefills.rules = table.concat(visual_selection_info.lines, '\n')
    elseif visualSelectionUsage == 'operate-within-range' then
      prefills.paths = utils.get_visual_selection_info_as_str(visual_selection_info)
    end
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
