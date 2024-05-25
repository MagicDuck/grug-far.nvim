local utils = require('grug-far/utils')
local M = {}

-- TODO (sbadragan): expand this to work with project specific
function M.getHistoryFilename()
  local hist_dir = vim.fn.stdpath('state') .. '/grug-far'
  if vim.fn.isdirectory(hist_dir) == 0 then
    vim.fn.mkdir(hist_dir)
  end

  return hist_dir .. '/history'
end

--- adds entry to history
---@param inputs GrugFarInputs
function M.addHistoryEntry(inputs, callback)
  local historyFilename = M.getHistoryFilename()
  local cb = vim.schedule_wrap(callback)
  utils.readFileAsync(historyFilename, function(err, contents)
    if err then
      cb(err)
    end

    -- TODO (sbadragan): parse contents and dedupe
    local newContents = '\nSearch: '
      .. inputs.search
      .. '\nReplace: '
      .. inputs.replacement
      .. '\nFiles Filter: '
      .. inputs.filesFilter
      .. '\nFlags: '
      .. inputs.flags
      .. '\n'
      .. contents

    utils.overwriteFileAsync(historyFilename, newContents, cb)
  end)
end

--- gets first value on entry line starting with given pattern
---@param entryLines string[]
---@param pattern string
local function getFirstValueStartingWith(entryLines, pattern)
  for _, line in ipairs(entryLines) do
    local i, j = string.find(line, pattern)
    if i == 1 then
      return line:sub(j + 1)
    end
  end

  return ''
end

---@class HistoryEntry
---@field search string
---@field replacement string
---@field filesFilter string
---@field flags string

--- gets history entry from list of lines
---@param lines string[]
---@return HistoryEntry
function M.getHistoryEntryFromLines(lines)
  return {
    search = getFirstValueStartingWith(lines, 'Search:[ ]?'),
    replacement = getFirstValueStartingWith(lines, 'Replace:[ ]?'),
    filesFilter = getFirstValueStartingWith(lines, 'Files Filter:[ ]?'),
    flags = getFirstValueStartingWith(lines, 'Flags:[ ]?'),
  }
end

return M
