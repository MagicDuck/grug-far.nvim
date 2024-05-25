local utils = require('grug-far/utils')
local M = {}

---@param context GrugFarContext
---@return string
function M.getHistoryFilename(context)
  local historyDir = context.options.history.historyDir
  if vim.fn.isdirectory(historyDir) == 0 then
    vim.fn.mkdir(historyDir, 'p')
  end

  local file = historyDir .. '/history'
  if vim.fn.filereadable(file) == 0 then
    vim.fn.writefile({ '' }, file)
  end

  return file
end

--- adds entry to history
---@param context GrugFarContext
---@param notify? boolean
function M.addHistoryEntry(context, notify)
  local inputs = context.state.inputs
  local historyFilename = M.getHistoryFilename(context)
  local callback = vim.schedule_wrap(function(err)
    if notify then
      if err then
        vim.notify('grug-far: could not add to history: ' .. err, vim.log.levels.ERROR)
      else
        vim.notify('grug-far: added current search to history!', vim.log.levels.INFO)
      end
    end
  end)

  utils.readFileAsync(historyFilename, function(err, contents)
    if err then
      callback(err)
    end

    local entry = '\n\nSearch: '
      .. inputs.search
      .. '\nReplace: '
      .. inputs.replacement
      .. '\nFiles Filter: '
      .. inputs.filesFilter
      .. '\nFlags: '
      .. inputs.flags
      .. '\n'

    -- dedupe last entry
    local newContents = contents or ''
    if not vim.startswith(newContents, entry) then
      newContents = entry .. contents
    end

    -- ensure max history lines
    local lines = vim.split(newContents, '\n')
    local maxHistoryLines = context.options.history.maxHistoryLines
    if #lines > maxHistoryLines then
      local firstEmptyLine
      for i = maxHistoryLines, 1, -1 do
        if #lines[i] == 0 then
          firstEmptyLine = i
          break
        end
      end
      lines = vim.list_slice(lines, 1, firstEmptyLine)
      newContents = table.concat(lines, '\n')
    end

    utils.overwriteFileAsync(historyFilename, newContents, callback)
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
