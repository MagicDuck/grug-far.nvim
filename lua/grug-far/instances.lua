---@class GrugFarInstance
---@field _context GrugFarContext
---@field _buf integer
---@field _params { context: GrugFarContext, buf: integer }
local M = {}

M.__index = M

---@alias GrugFarInstanceQuery string | number | nil

---@type table<string, GrugFarInstance>
local instances = {}

--- add instance with given name
---@param instanceName string
---@param inst GrugFarInstance
function M.add_instance(instanceName, inst)
  instances[instanceName] = inst
end

--- removes instance with given name
---@param instanceName string
function M.remove_instance(instanceName)
  instances[instanceName] = nil
end

--- check if given instance exists
---@param instanceName string
---@return boolean
function M.has_instance(instanceName)
  return not not instances[instanceName]
end

--- returns instance name associated with given buf number
--- if given buf number is 0, returns instance for current buffer
---@param buf integer (same argument as for bufnr())
---@return GrugFarInstance? inst, string? instanceName
function M.get_instance_by_buf(buf)
  local bufnr = vim.fn.bufnr(buf)
  for instanceName, inst in pairs(instances) do
    if inst._buf == bufnr then
      return inst, instanceName
    end
  end
end

--- gets instance for given query
---@param instQuery GrugFarInstanceQuery
---@return GrugFarInstance? inst, string? instanceName
function M.get_instance(instQuery)
  if type(instQuery) == 'string' then
    return instances[instQuery], instQuery
  end

  if type(instQuery) == 'number' then
    return M.get_instance_by_buf(instQuery)
  end

  if instQuery == nil then
    -- use first available
    for instanceName, instance in pairs(instances) do
      return instance, instanceName
    end
  end
end

--- gets instance for given query, erroring out if not available
---@param instQuery GrugFarInstanceQuery
---@return GrugFarInstance inst, string instanceName
function M.ensure_instance(instQuery)
  local inst, instName = M.get_instance(instQuery)
  if inst and instName then
    return inst, instName
  end

  local msg
  if type(instQuery) == 'string' then
    msg = 'name="' .. instQuery .. '"'
  elseif type(instQuery == 'number') then
    msg = 'buf=' .. instQuery
  end
  if msg then
    error('No grug-far instance with ' .. msg .. '!')
  else
    error('No grug-far instance!')
  end
end

--- Returns an object representing an instance of grug-far
---@param context GrugFarContext
---@param buf integer
function M.new(context, buf)
  local self = setmetatable({}, M)
  self._context = context
  self._buf = buf
  self._params = { context = context, buf = buf }
  return self
end

--- gets buffer associated with instance
---@return integer
function M:get_buf()
  return self._buf
end

--- checks if this instance is still valid (maybe has been closed in between)
---@return boolean
function M:is_valid()
  return M.get_instance_by_buf(self._buf) == self
end

--- ensure instance is valid or error out
function M:_ensure_valid()
  if not self:is_valid() then
    error('Invalid grug-far instance!')
  end
end

--- is instance window open
---@return boolean
function M:is_open()
  self:_ensure_valid()
  local win = vim.fn.bufwinid(self._buf)
  return win ~= -1
end

--- ensure instance window is open
function M:ensure_open()
  self:_ensure_valid()

  if not self:is_open() then
    -- toggle it on
    local win = require('grug-far')._createWindow(self._context)
    vim.api.nvim_win_set_buf(win, self._buf)
  end
end

--- show help
function M:help()
  self:ensure_open()
  require('grug-far.actions.help')(self._params)
end

--- perform replace
function M:replace()
  self:ensure_open()
  require('grug-far.actions.replace')(self._params)
end

--- perform sync all
function M:sync_all()
  self:ensure_open()
  require('grug-far.actions.syncLocations')(self._params)
end

--- perform sync line (for current line)
function M:sync_line()
  self:ensure_open()
  require('grug-far.actions.syncLine')(self._params)
end

--- perform sync file (for file around current line)
function M:sync_file()
  self:ensure_open()
  require('grug-far.actions.syncFile')(self._params)
end

--- open history window
function M:history_open()
  self:ensure_open()
  require('grug-far.actions.historyOpen')(self._params)
end

--- add current input values as a new history entry
function M:history_add()
  self:ensure_open()
  require('grug-far.actions.historyAdd')(self._params)
end

--- perform search
function M:search()
  self:ensure_open()
  require('grug-far.actions.search')(self._params)
end

--- move cursor to <count>th match
---@param count number
function M:goto_match(count)
  self:ensure_open()
  require('grug-far.actions.gotoMatch')(vim.tbl_extend('keep', self._params, { count = count }))
end

--- move cursor to next match
--- if includeUncounted = true, it will move through lines that do not have a match count
--- (which can happen for multiline searches)
---@param params? { includeUncounted?: boolean }
function M:goto_next_match(params)
  self:ensure_open()
  require('grug-far.actions.gotoMatch')(
    vim.tbl_extend('keep', self._params, { increment = 1 }, params or {})
  )
end

--- move cursor to prev match
--- if includeUncounted = true, it will move through lines that do not have a match count
--- (which can happen for multiline searches)
---@param params? { includeUncounted?: boolean }
function M:goto_prev_match(params)
  self:ensure_open()
  require('grug-far.actions.gotoMatch')(
    vim.tbl_extend('keep', self._params, { increment = -1 }, params or {})
  )
end

--- goto source location (file, line, column) associated with current line
function M:goto_location()
  self:ensure_open()
  require('grug-far.actions.gotoLocation')(self._params)
end

--- open source location (file, line, column) associated with current line (stays in grug-far buffer)
function M:open_location()
  self:ensure_open()
  require('grug-far.actions.openLocation')(self._params)
end

--- 1. apply change at current line (and notify if notify=true)
--- 2. optionally remove it from buffer (if remove_synced = true, defaults to true)
--- 3. move cursor to next match
--- 4.open source location (if open_location = true, defaults to true)
---@param params? { open_location?: boolean, remove_synced?: boolean, notify?: boolean }
function M:apply_next_change(params)
  self:ensure_open()
  require('grug-far.actions.applyChange')(
    vim.tbl_extend('keep', self._params, { increment = 1 }, params)
  )
end

--- 1. apply change at current line (and notify if notify=true)
--- 2. optionally remove it from buffer (if remove_synced = true, defaults to true)
--- 3. move cursor to prev match
--- 4.open source location (if open_location = true, defaults to true)
---@param params? { open_location?: boolean, remove_synced?: boolean, notify?: boolean }
function M:apply_prev_change(params)
  self:ensure_open()
  require('grug-far.actions.applyChange')(
    vim.tbl_extend('keep', self._params, { increment = -1 }, params)
  )
end

--- send result lines to the quickfix list. Deleting result lines will cause them not to be included.
function M:open_quickfix()
  self:_ensure_valid()
  require('grug-far.actions.qflist')(self._params)
end

--- abort current operation. Can be useful if you've ended up doing too large of a search or
--- if you've changed your mind about a replacement midway.
function M:abort()
  self:_ensure_valid()
  require('grug-far.actions.abort')(self._params)
end

--- Close grug-far buffer/window. This is the same as `:bd` except that it will also ask you
--- to confirm if there is a replace/sync in progress, as those would be aborted.
function M:close()
  self:_ensure_valid()
  require('grug-far.actions.close')(self._params)
end

--- hides grug-far window (but instance is still valid)
function M:hide()
  self:_ensure_valid()
  local win = vim.fn.bufwinid(self._buf)
  if win ~= -1 then
    vim.api.nvim_win_close(win, true)
  end
end

--- opens/focuses grug-far window
function M:open()
  self:ensure_open()

  -- focus it
  local win = vim.fn.bufwinid(self._buf)
  vim.api.nvim_set_current_win(win)
end

--- swaps search engine with the next one as configured through options.enabledEngines
function M:swap_engine()
  self:ensure_open()
  require('grug-far.actions.swapEngine')(self._params)
end

--- toggle showing search command. Can be useful for debugging purposes.
function M:toggle_show_search_command()
  self:ensure_open()
  require('grug-far.actions.toggleShowCommand')(self._params)
end

--- preview source location associated with current line in a floating window
function M:preview_location()
  self:ensure_open()
  require('grug-far.actions.previewLocation')(self._params)
end

--- swaps replacement interperter with the next one as configured through
--- options.enabledReplacementInterpreters
function M:swap_replacement_interpreter()
  self:ensure_open()
  require('grug-far.actions.swapReplacementInterpreter')(self._params)
end

--- move cursor to input with given name
---@param inputName GrugFarInputName
function M:goto_input(inputName)
  self:ensure_open()
  require('grug-far.inputs').goto_input(self._context, self._buf, inputName)
end

--- move cursor to first input
function M:goto_first_input()
  self:ensure_open()
  require('grug-far.inputs').goto_first_input(self._context, self._buf)
end

--- move cursor to next input
function M:goto_next_input()
  self:ensure_open()
  require('grug-far.inputs').goto_next_input(self._context, self._buf)
end

--- move cursor to prev input
function M:goto_prev_input()
  self:ensure_open()
  require('grug-far.inputs').goto_prev_input(self._context, self._buf)
end

--- update input values to new ones
--- if clearOld=true is given, the old input values are ignored
---@param values GrugFarPrefills
---@param clearOld boolean
function M:update_input_values(values, clearOld)
  self:ensure_open()

  vim.schedule(function()
    require('grug-far.inputs').fill(self._context, self._buf, values, clearOld)
  end)
end

--- toggles given list of flags
---@param flags string[]
---@return boolean[] states
function M:toggle_flags(flags)
  self:ensure_open()
  return require('grug-far.inputs').toggle_flags(self._context, self._buf, flags)
end

return M
