local search = require('grug-far.engine.astgrep.search')
local replace = require('grug-far.engine.astgrep.replace')

local shallow_copy_table = function(tbl)
  local copy = {}
  for k, v in pairs(tbl) do
    copy[k] = v
  end
  return copy
end

---@type GrugFarEngine
local AstgrepEngine = {
  type = 'astgrep-rules',

  isSearchWithReplacement = function(raw, options)
    -- todo: stop patching `s/search/rules/`, once per-engine inputs land
    local inputs = shallow_copy_table(raw)
    inputs.rules = inputs.search
    inputs.search = nil

    local args = search.getSearchArgs(inputs, options)
    return search.isSearchWithReplacement(args)
  end,

  showsReplaceDiff = function()
    return true
  end,

  search = function(raw)
    local params = shallow_copy_table(raw)
    params.inputs = shallow_copy_table(params.inputs)
    params.inputs.rules = params.inputs.search
    params.inputs.search = nil

    return search.search(params)
  end,

  replace = function(raw)
    local params = shallow_copy_table(raw)
    params.inputs = shallow_copy_table(params.inputs)
    params.inputs.rules = params.inputs.search
    params.inputs.search = nil

    return replace.replace(params)
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
