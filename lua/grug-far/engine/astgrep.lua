local utils = require('grug-far/utils')
local search = require('grug-far/engine/astgrep/search')
local replace = require('grug-far/engine/astgrep/replace')

--- is doing a search with replacement?
---@param args string[]?
---@return boolean
local function isSearchWithReplacement(args)
  if not args then
    return false
  end

  for i = 1, #args do
    if vim.startswith(args[i], '--rewrite=') or args[i] == '--rewrite' or args[i] == '-r' then
      return true
    end
  end

  return false
end

---@type GrugFarEngine
local AstgrepEngine = {
  type = 'astgrep',

  isSearchWithReplacement = function(inputs, options)
    local args = search.getSearchArgs(inputs, options)
    return isSearchWithReplacement(args)
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
