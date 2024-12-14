local utils = require('grug-far.utils')
local M = {}

local continuation_prefix = '| '
local engine_field_sep = '|'

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

--- formats input value for history entry, handling multiline appropriately
---@param value string
---@return string
local function formatInputValue(value)
  local lines = vim.split(value, '\n')
  local result = {}
  for i, line in ipairs(lines) do
    table.insert(result, i == 1 and line or continuation_prefix .. line)
  end
  return table.concat(result, '\n')
end

--- adds entry to history
---@param context GrugFarContext
---@param notify? boolean
function M.addHistoryEntry(context, notify)
  local inputs = context.state.inputs
  if
    #inputs.search + #inputs.replacement + #inputs.flags + #inputs.filesFilter + #inputs.paths == 0
  then
    return -- nothing to save
  end
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

    vim.schedule(function()
      local entry = '\n\nEngine: '
        .. context.engine.type
        .. (context.replacementInterpreter and engine_field_sep .. context.replacementInterpreter.type or '')
        .. '\nSearch: '
        .. formatInputValue(inputs.search)
        .. '\nReplace: '
        .. formatInputValue(inputs.replacement)
        .. '\nFiles Filter: '
        .. formatInputValue(inputs.filesFilter)
        .. '\nFlags: '
        .. formatInputValue(inputs.flags)
        .. '\nPaths: '
        .. formatInputValue(inputs.paths)
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
  end)
end

--- gets first value on entry line starting with given pattern
--- values can be continued on follow up lines by prefixing them with the continuation_prefix
---@param entryLines string[]
---@param pattern string
local function getFirstValueStartingWith(entryLines, pattern)
  local value = ''
  local foundStart = false
  for _, line in ipairs(entryLines) do
    if foundStart then
      if line:sub(1, #continuation_prefix) == continuation_prefix then
        value = value .. '\n' .. line:sub(3, -1)
      else
        break
      end
    else
      local i, j = string.find(line, pattern)
      if i == 1 then
        value = line:sub(j + 1)
        foundStart = true
      end
    end
  end

  return value
end

---@class HistoryEntry
---@field engine string
---@field replacementInterpreter? string
---@field search string
---@field replacement string
---@field filesFilter string
---@field flags string
---@field paths string

--- gets history entry from list of lines
---@param lines string[]
---@return HistoryEntry
function M.getHistoryEntryFromLines(lines)
  local engine_val = getFirstValueStartingWith(lines, 'Engine:[ ]?')
  local engine, replacementInterpreter = unpack(vim.split(engine_val, engine_field_sep))

  return {
    engine = vim.trim(engine),
    replacementInterpreter = replacementInterpreter and vim.trim(replacementInterpreter) or nil,
    search = getFirstValueStartingWith(lines, 'Search:[ ]?'),
    replacement = getFirstValueStartingWith(lines, 'Replace:[ ]?'),
    filesFilter = getFirstValueStartingWith(lines, 'Files Filter:[ ]?'),
    flags = getFirstValueStartingWith(lines, 'Flags:[ ]?'),
    paths = getFirstValueStartingWith(lines, 'Paths:[ ]?'),
  }
end

return M
