local utils = require('grug-far.utils')
local inputs = require('grug-far.inputs')
local replacementInterpreter = require('grug-far.replacementInterpreter')
local engine = require('grug-far.engine')
local resultsList = require('grug-far.render.resultsList')
local search = require('grug-far.actions.search')
local M = {}

local continuation_prefix = '| '
local engine_field_sep = '|'

---@param context grug.far.Context
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
---@param context grug.far.Context
---@param buf integer
---@param notify? boolean
function M.addHistoryEntry(context, buf, notify)
  local inputsLen = 0
  local _inputs = inputs.getValues(context, buf)
  for _, input in ipairs(context.engine.inputs) do
    local value = _inputs[input.name]
    inputsLen = inputsLen + #value
  end

  if inputsLen == 0 then
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
        .. (
          context.replacementInterpreter
            and engine_field_sep .. context.replacementInterpreter.type
          or ''
        )
      for _, input in ipairs(context.engine.inputs) do
        entry = entry .. '\n' .. input.label .. ': ' .. formatInputValue(_inputs[input.name])
      end
      entry = entry .. '\n'

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

---@class grug.far.HistoryEntry
---@field engine string
---@field replacementInterpreter? string
---@field search string
---@field replacement string
---@field filesFilter string
---@field flags string
---@field paths string

--- gets history entry from list of lines
---@param lines string[]
---@return grug.far.HistoryEntry
function M.getHistoryEntryFromLines(lines)
  local engine_val = getFirstValueStartingWith(lines, 'Engine:[ ]?')
  local engineType, _replacementInterpreter = unpack(vim.split(engine_val, engine_field_sep))

  local entry = {
    engine = vim.trim(engineType),
    replacementInterpreter = _replacementInterpreter and vim.trim(_replacementInterpreter) or nil,
  }

  local _engine = engine.getEngine(engineType)
  for _, input in ipairs(_engine.inputs) do
    entry[input.name] = getFirstValueStartingWith(lines, input.label .. ':[ ]?')
  end

  return entry
end

--- fills inputs based on a history entry
---@param context grug.far.Context
---@param buf integer
---@param entry grug.far.HistoryEntry
---@param callback? fun()
function M.fillInputsFromEntry(context, buf, entry, callback)
  context.state.searchDisabled = true

  local _inputs = inputs.getValues(context, buf)
  context.engine = engine.getEngine(entry.engine)

  -- get the values and stuff them into savedValues
  for name, value in pairs(_inputs) do
    context.state.previousInputValues[name] = value
  end
  -- clear the values and input label extmarks from the buffer
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, {})
  vim.api.nvim_buf_clear_namespace(buf, context.namespace, 0, -1)
  context.extmarkIds = {}

  vim.schedule(function()
    inputs.fill(context, buf, entry --[[@as grug.far.Prefills]], true)
    if entry.replacementInterpreter then
      replacementInterpreter.setReplacementInterpreter(buf, context, entry.replacementInterpreter)
    end

    local win = vim.fn.bufwinid(buf)
    pcall(vim.api.nvim_win_set_cursor, win, { context.options.startCursorRow, 0 })
    resultsList.clear(buf, context)
    if callback then
      callback()
    end

    search({ buf = buf, context = context })
    -- prevent search on change (double search) since we are searching manually already
    context.state.lastInputs = vim.deepcopy(inputs.getValues(context, buf))
    context.state.searchDisabled = false
  end)
end

return M
