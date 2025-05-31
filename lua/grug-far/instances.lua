--- *grug-far-instance-api*

local inst

---exclude static class api from from documentation
---@private
do
  ---@class grug.far.Instance
  ---@field _context grug.far.Context
  ---@field _buf integer
  ---@field _params { context: grug.far.Context, buf: integer }
  ---@field _is_ready boolean
  ---@field _on_ready_fns [fun()]
  inst = {}
  inst.__index = inst

  ---@type table<string, grug.far.Instance>
  local instances = {}

  --- add instance with given name
  ---@param instanceName string
  ---@param instance grug.far.Instance
  function inst.add_instance(instanceName, instance)
    instances[instanceName] = instance
  end

  --- removes instance with given name
  ---@param instanceName string
  function inst.remove_instance(instanceName)
    instances[instanceName] = nil
  end

  --- check if given instance exists
  ---@param instanceName string
  ---@return boolean
  function inst.has_instance(instanceName)
    return not not instances[instanceName]
  end

  --- returns instance name associated with given buf number
  --- if given buf number is 0, returns instance for current buffer
  ---@param buf integer (same argument as for bufnr())
  ---@return grug.far.Instance? inst
  ---@return string? instanceName
  function inst.get_instance_by_buf(buf)
    local bufnr = vim.fn.bufnr(buf)
    for instanceName, instance in pairs(instances) do
      if instance._buf == bufnr then
        return instance, instanceName
      end
    end
  end

  --- gets instance for given query
  ---@param instQuery grug.far.InstanceQuery
  ---@return grug.far.Instance? inst
  ---@return string? instanceName
  function inst.get_instance(instQuery)
    if type(instQuery) == 'string' then
      return instances[instQuery], instQuery
    end

    if type(instQuery) == 'number' then
      return inst.get_instance_by_buf(instQuery)
    end

    if instQuery == nil then
      -- try to find one in current tabpage
      local tabpage = vim.api.nvim_get_current_tabpage()
      local tabpage_windows = vim.api.nvim_tabpage_list_wins(tabpage)
      for _, win in ipairs(tabpage_windows) do
        local buf = vim.api.nvim_win_get_buf(win)
        local instance, instanceName = inst.get_instance_by_buf(buf)
        if instance then
          return instance, instanceName
        end
      end

      -- use first available
      for instanceName, instance in pairs(instances) do
        return instance, instanceName
      end
    end
  end

  --- gets instance for given query, erroring out if not available
  ---@param instQuery grug.far.InstanceQuery
  ---@return grug.far.Instance? inst
  ---@return string? instanceName
  function inst.ensure_instance(instQuery)
    local instance, instName = inst.get_instance(instQuery)
    if instance and instName then
      return instance, instName
    end

    local msg
    if type(instQuery) == 'string' then
      msg = 'name="' .. instQuery .. '"'
    elseif type(instQuery) == 'number' then
      msg = 'buf=' .. instQuery
    end
    if msg then
      error('No grug-far instance with ' .. msg .. '!')
    else
      error('No grug-far instance!')
    end
  end

  --- Returns an object representing an instance of grug-far
  ---@param context grug.far.Context
  ---@param buf integer
  function inst.new(context, buf)
    local self = setmetatable({}, inst)
    self._context = context
    self._buf = buf
    self._params = { context = context, buf = buf }
    self._is_ready = false
    self._on_ready_fns = {}
    return self
  end
end

function inst:_set_ready()
  self._is_ready = true

  -- exec any outstanding ready fns
  for _, fn in ipairs(self._on_ready_fns) do
    fn()
  end
  self._on_ready_fns = {}
end

--- executes given callback when the instance has been rendered and is ready
--- if that has already happened, the callback is executed immediately
---@param callback fun()
function inst:when_ready(callback)
  if self._is_ready then
    callback()
  else
    table.insert(self._on_ready_fns, callback)
  end
end

--- gets buffer associated with instance
---@return integer buf
function inst:get_buf()
  return self._buf
end

--- checks if this instance is still valid (maybe has been closed in between)
---@return boolean is_valid
function inst:is_valid()
  return inst.get_instance_by_buf(self._buf) == self
end

--- ensure instance is valid or error out
---@private
function inst:_ensure_valid()
  if not self:is_valid() then
    error('Invalid grug-far instance!')
  end
end

--- is instance window open
---@return boolean is_open
function inst:is_open()
  self:_ensure_valid()
  local win = vim.fn.bufwinid(self._buf)
  return win ~= -1
end

--- ensure instance window is open
function inst:ensure_open()
  self:_ensure_valid()

  if not self:is_open() then
    -- toggle it on
    local win = require('grug-far')._createWindow(self._context)
    vim.api.nvim_win_set_buf(win, self._buf)
    require('grug-far')._setupWindow(self._context, win, self._buf)
  end
end

--- show help
function inst:help()
  self:ensure_open()
  require('grug-far.actions.help')(self._params)
end

--- perform replace
function inst:replace()
  self:ensure_open()
  require('grug-far.actions.replace')(self._params)
end

--- perform sync all
function inst:sync_all()
  self:ensure_open()
  require('grug-far.actions.syncLocations')(self._params)
end

--- perform sync line (for current line)
function inst:sync_line()
  self:ensure_open()
  require('grug-far.actions.syncLine')(self._params)
end

--- perform sync file (for file around current line)
function inst:sync_file()
  self:ensure_open()
  require('grug-far.actions.syncFile')(self._params)
end

--- open history window
function inst:history_open()
  self:ensure_open()
  require('grug-far.actions.historyOpen')(self._params)
end

--- add current input values as a new history entry
function inst:history_add()
  self:ensure_open()
  require('grug-far.actions.historyAdd')(self._params)
end

--- perform search
function inst:search()
  self:ensure_open()
  require('grug-far.actions.search')(self._params)
end

--- move cursor to <count>th match
---@param count number
function inst:goto_match(count)
  self:ensure_open()
  require('grug-far.actions.gotoMatch')(vim.tbl_extend('keep', self._params, { count = count }))
end

--- move cursor to next match
--- if includeUncounted = true, it will move through lines that do not have a match count
--- (which can happen for multiline searches)
---@param params? { includeUncounted?: boolean, wrap?: boolean  }
---@return boolean hasMoved
function inst:goto_next_match(params)
  self:ensure_open()
  local location = require('grug-far.actions.gotoMatch')(
    vim.tbl_extend('keep', self._params, { increment = 1 }, params or {})
  )
  return not not location
end

--- move cursor to prev match
--- if includeUncounted = true, it will move through lines that do not have a match count
--- (which can happen for multiline searches)
---@param params? { includeUncounted?: boolean, wrap?: boolean }
---@return boolean hasMoved
function inst:goto_prev_match(params)
  self:ensure_open()
  local location = require('grug-far.actions.gotoMatch')(
    vim.tbl_extend('keep', self._params, { increment = -1 }, params or {})
  )
  return not not location
end

--- goto source location (file, line, column) associated with current line
function inst:goto_location()
  self:ensure_open()
  require('grug-far.actions.gotoLocation')(self._params)
end

--- open source location (file, line, column) associated with current line (stays in grug-far buffer)
function inst:open_location()
  self:ensure_open()
  require('grug-far.actions.openLocation')(
    vim.tbl_extend(
      'keep',
      self._params,
      { useScratchBuffer = self._context.options.openTargetWindow.useScratchBuffer }
    )
  )
end

--- 1. apply change at current line (and notify if notify=true)
--- 2. optionally remove it from buffer (if remove_synced = true, defaults to true)
--- 3. move cursor to next match
--- 4. open source location (if open_location = true, defaults to true)
---@param params? { open_location?: boolean, remove_synced?: boolean, notify?: boolean }
function inst:apply_next_change(params)
  self:ensure_open()
  require('grug-far.actions.applyChange')(
    vim.tbl_extend('keep', self._params, { increment = 1 }, params or {})
  )
end

--- 1. apply change at current line (and notify if notify=true)
--- 2. optionally remove it from buffer (if remove_synced = true, defaults to true)
--- 3. move cursor to prev match
--- 4. open source location (if open_location = true, defaults to true)
---@param params? { open_location?: boolean, remove_synced?: boolean, notify?: boolean }
function inst:apply_prev_change(params)
  self:ensure_open()
  require('grug-far.actions.applyChange')(
    vim.tbl_extend('keep', self._params, { increment = -1 }, params or {})
  )
end

--- send result lines to the quickfix list. Deleting result lines will cause them not to be included.
function inst:open_quickfix()
  self:_ensure_valid()
  require('grug-far.actions.qflist')(self._params)
end

--- abort current operation. Can be useful if you've ended up doing too large of a search or
--- if you've changed your mind about a replacement midway.
function inst:abort()
  self:_ensure_valid()
  require('grug-far.actions.abort')(self._params)
end

--- Close grug-far buffer/window. This is the same as `:bd` except that it will also ask you
--- to confirm if there is a replace/sync in progress, as those would be aborted.
function inst:close()
  self:_ensure_valid()
  require('grug-far.actions.close')(self._params)
end

--- hides grug-far window (but instance is still valid)
function inst:hide()
  self:_ensure_valid()
  local win = vim.fn.bufwinid(self._buf)
  if win ~= -1 then
    vim.api.nvim_win_close(win, true)
  end
end

--- opens/focuses grug-far window
function inst:open()
  self:ensure_open()

  -- focus it
  local win = vim.fn.bufwinid(self._buf)
  vim.api.nvim_set_current_win(win)
end

--- swaps search engine with the next one as configured through options.enabledEngines
function inst:swap_engine()
  self:ensure_open()
  require('grug-far.actions.swapEngine')(self._params)
end

--- toggle showing search command. Can be useful for debugging purposes.
function inst:toggle_show_search_command()
  self:ensure_open()
  require('grug-far.actions.toggleShowCommand')(self._params)
end

--- preview source location associated with current line in a floating window
function inst:preview_location()
  self:ensure_open()
  require('grug-far.actions.previewLocation')(self._params)
end

--- swaps replacement interperter with the next one as configured through
--- options.enabledReplacementInterpreters
function inst:swap_replacement_interpreter()
  self:ensure_open()
  require('grug-far.actions.swapReplacementInterpreter')(self._params)
end

--- move cursor to input with given name
---@param inputName grug.far.InputName
function inst:goto_input(inputName)
  self:ensure_open()
  require('grug-far.inputs').goto_input(self._context, self._buf, inputName)
end

--- move cursor to first input
function inst:goto_first_input()
  self:ensure_open()
  require('grug-far.inputs').goto_first_input(self._context, self._buf)
end

--- move cursor to next input
function inst:goto_next_input()
  self:ensure_open()
  require('grug-far.inputs').goto_next_input(self._context, self._buf)
end

--- move cursor to prev input
function inst:goto_prev_input()
  self:ensure_open()
  require('grug-far.inputs').goto_prev_input(self._context, self._buf)
end

--- update input values to new ones
--- if clearOld=true is given, the old input values are ignored
---@param values grug.far.Prefills
---@param clearOld boolean
function inst:update_input_values(values, clearOld)
  self:ensure_open()
  vim.schedule(function()
    require('grug-far.inputs').fill(self._context, self._buf, values, clearOld)
  end)
end

--- toggles given list of flags
---@param flags string[]
---@return boolean[] states
function inst:toggle_flags(flags)
  self:ensure_open()
  return require('grug-far.inputs').toggle_flags(self._context, self._buf, flags)
end

--- gets status info
---@return {
---   status: grug.far.Status,
---   stats?: { matches: integer, files: integer },
---   actionMessage?: string,
---   engineType: string,
---   interpreterType?: string,
---   normalModeSearch: boolean,
--- }
function inst:get_status_info()
  self:_ensure_valid()
  local context = self._context
  return {
    status = context.state.status,
    stats = context.state.stats,
    actionMessage = context.state.actionMessage,
    engineType = context.engine.type,
    interpreterType = context.replacementInterpreter and context.replacementInterpreter.type or nil,
    normalModeSearch = context.state.normalModeSearch,
  }
end

return inst
