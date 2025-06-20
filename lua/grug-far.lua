--- *grug-far-api*

local grug_far = {}

---@alias grug.far.InstanceQuery string | number | nil

---@alias grug.far.InputName "search" | "rules" | "replacement" | "filesFilter" | "flags" | "paths"

---@alias grug.far.Prefills {
---   search?: string,
---   rules?: string,
---   replacement?: string,
---   filesFilter?: string,
---   flags?: string,
---   paths?: string,
--- }

local contextCount = 0

require('grug-far.highlights').setup()

--- set up grug-far
--- sets global options, which can also be configured through vim.g.grug_far
---@param options? grug.far.OptionsOverride partial override of |grug_far.defaultOptions|
---@seealso Option types: |grug.far.Options|
function grug_far.setup(options)
  require('grug-far.opts').setGlobalOptionsOverride(options)
end

--- generate instance specific context
---@param options grug.far.Options
---@return grug.far.Context
---@private
local function createContext(options)
  contextCount = contextCount + 1

  local context = {
    count = contextCount,
    options = options,
    engine = require('grug-far.engine').getEngine(options.engine),
    replacementInterpreter = require('grug-far.replacementInterpreter').getReplacementInterpreter(
      options.replacementInterpreter
    ),
    namespace = vim.api.nvim_create_namespace('grug-far-namespace'),
    locationsNamespace = vim.api.nvim_create_namespace(''),
    resultListNamespace = vim.api.nvim_create_namespace(''),
    historyHlNamespace = vim.api.nvim_create_namespace(''),
    helpHlNamespace = vim.api.nvim_create_namespace(''),
    bufrangeNamespace = vim.api.nvim_create_namespace(''),
    augroup = vim.api.nvim_create_augroup('grug-far.nvim-augroup-' .. contextCount, {}),
    extmarkIds = {},
    actions = {},
    fileIconsProvider = options.icons.enabled
        and require('grug-far.fileIconsProvider').getProvider(options.icons.fileIconsProvider)
      or nil,
    throttledOnStatusChange = require('grug-far.utils').throttle(
      options.onStatusChange,
      options.onStatusChangeThrottleTime
    ),
    state = {
      inputs = {},
      resultLocationByExtmarkId = {},
      resultMatchLineCount = 0,
      lastCursorLocation = nil,
      tasks = {},
      showSearchCommand = false,
      bufClosed = false,
      highlightRegions = {},
      highlightResults = {},
      normalModeSearch = options.normalModeSearch,
      searchDisabled = false,
      previousInputValues = {},
    },
  }

  ---@diagnostic disable-next-line: inject-field
  options.__grug_far_context__ = context

  return context
end

--- quality of life highlight of buf range for operate-within-range
---@param buf integer
---@param context grug.far.Context
---@private
local function setupBufRangeHighlight(buf, context)
  local bufrangeInputName = context.engine.bufrangeInputName
  if not bufrangeInputName then
    return
  end

  local inputs = require('grug-far.inputs')
  local utils = require('grug-far.utils')
  local bufrange_input_val = ''
  local highlighted_buffer = nil

  local removeBufrangeHighlight = function()
    if highlighted_buffer then
      vim.api.nvim_buf_clear_namespace(highlighted_buffer, context.bufrangeNamespace, 0, -1)
      highlighted_buffer = nil
    end
  end

  local addBufrangeHighlight = function(bufrange_input_str)
    local bufrange, bufrange_err = utils.getBufrange(bufrange_input_str)
    if not bufrange or bufrange_err then
      removeBufrangeHighlight()
      return
    end

    local origin_buf = vim.fn.bufnr(bufrange.file_name)
    if highlighted_buffer and origin_buf ~= highlighted_buffer then
      removeBufrangeHighlight()
    end
    highlighted_buffer = origin_buf

    vim.hl.range(
      origin_buf,
      context.bufrangeNamespace,
      'GrugFarVisualBufrange',
      { bufrange.start_row - 1, bufrange.start_col },
      { bufrange.end_row - 1, bufrange.end_col }
    )
  end

  -- make sure highlight is applied on bufrange change
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = context.augroup,
    buffer = buf,
    callback = vim.schedule_wrap(function()
      local input_value = inputs.getInputValue(context, buf, bufrangeInputName)
      if bufrange_input_val ~= input_value then
        addBufrangeHighlight(input_value)
        bufrange_input_val = input_value
      end
    end),
  })

  -- make sure highlight is applied on entering grug buffer
  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    group = context.augroup,
    buffer = buf,
    callback = vim.schedule_wrap(function()
      local input_value = inputs.getInputValue(context, buf, bufrangeInputName)
      addBufrangeHighlight(input_value)
    end),
  })

  -- make sure highlight is removed on leaving grug buffer
  vim.api.nvim_create_autocmd({ 'BufLeave' }, {
    group = context.augroup,
    buffer = buf,
    callback = vim.schedule_wrap(function()
      removeBufrangeHighlight()
    end),
  })
end

---@param context grug.far.Context
---@return integer windowId
---@private
function grug_far._createWindow(context)
  context.prevWin = vim.api.nvim_get_current_win()
  local prevBuf = vim.api.nvim_win_get_buf(context.prevWin)
  context.prevBufName = vim.api.nvim_buf_get_name(prevBuf)
  context.prevBufFiletype = vim.bo[prevBuf].filetype

  vim.cmd(context.options.windowCreationCommand)
  local win = vim.api.nvim_get_current_win()

  return win
end

---@param context grug.far.Context
---@param win integer
---@param buf integer
---@private
function grug_far._setupWindow(context, win, buf)
  if context.options.disableBufferLineNumbers then
    vim.wo[win][0].number = false
    vim.wo[win][0].relativenumber = false
  end

  vim.wo[win][0].wrap = context.options.wrap
  vim.wo[win][0].breakindent = true
  vim.wo[win][0].breakindentopt = context.options.breakindentopt
  if require('grug-far.opts').shouldConceal(context.options) then
    vim.wo[win][0].conceallevel = 1
  end

  require('grug-far.fold').setup(context, win, buf)
end

---@param buf integer
---@param context grug.far.Context
---@private
local function setupCleanup(buf, context)
  local instances = require('grug-far.instances')

  local function cleanup()
    local autoSave = context.options.history.autoSave
    if autoSave.enabled and autoSave.onBufDelete then
      require('grug-far.history').addHistoryEntry(context, buf)
    end

    require('grug-far.tasks').abortAndFinishAllTasks(context)
    context.state.bufClosed = true
    local _, instanceName = instances.get_instance_by_buf(buf)
    if instanceName then
      instances.remove_instance(context.options.instanceName)
    end

    vim.api.nvim_buf_clear_namespace(buf, context.locationsNamespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.namespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.historyHlNamespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.helpHlNamespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.bufrangeNamespace, 0, -1)
    vim.api.nvim_del_augroup_by_id(context.augroup)
    require('grug-far.render.treesitter').clear(buf)
    require('grug-far.fold').cleanup(context)
  end

  local function onBufUnload()
    local status, err = pcall(cleanup)
    if not status then
      vim.notify('grug-far: error on cleanup! Please report! Error:\n' .. err, vim.log.levels.ERROR)
    end
  end

  vim.api.nvim_create_autocmd({ 'BufUnload' }, {
    group = context.augroup,
    buffer = buf,
    callback = onBufUnload,
  })
end

--- launch grug-far with the given overrides
---@param options? grug.far.OptionsOverride partial override of |grug_far.defaultOptions|
---@return grug.far.Instance instance
---@seealso Option types: |grug.far.Options| and |grug-far-instance-api|
function grug_far.open(options)
  local opts = require('grug-far.opts')
  local resolvedOpts = opts.with_defaults(options or {}, opts.getGlobalOptions())
  local visual_selection_info
  if resolvedOpts.visualSelectionUsage ~= 'ignore' then
    visual_selection_info = require('grug-far.utils').get_current_visual_selection_info(true)
  end

  return grug_far._open_internal(resolvedOpts, { visual_selection_info = visual_selection_info })
end

--- launch grug-far with the given options and params
---@param options grug.far.Options
---@param params { visual_selection_info: grug.far.VisualSelectionInfo? }
---@return grug.far.Instance instance
---@private
function grug_far._open_internal(options, params)
  local instances = require('grug-far.instances')
  if options.instanceName and instances.has_instance(options.instanceName) then
    error('A grug-far instance with instanceName="' .. options.instanceName .. '" already exists!')
  end

  local context = createContext(options)
  if not options.instanceName then
    options.instanceName = '__grug_far_instance__' .. context.count
  end
  if params.visual_selection_info then
    options.prefills = context.engine.getInputPrefillsForVisualSelection(
      params.visual_selection_info,
      options.prefills,
      options.visualSelectionUsage
    )
  end

  local win = grug_far._createWindow(context)
  local buf = vim.api.nvim_create_buf(not context.options.transient, true)
  -- bind buf to win immediately, so we can get correct win in buf relative event like FileType.
  vim.api.nvim_win_set_buf(win, buf)

  local instance = instances.new(context, buf)

  grug_far._setupWindow(context, win, buf)
  setupCleanup(buf, context)
  instances.add_instance(options.instanceName, instance)

  if options.visualSelectionUsage == 'operate-within-range' then
    setupBufRangeHighlight(buf, context)
  end

  require('grug-far.farBuffer').setupBuffer(win, buf, context, function()
    instance:_set_ready()
  end)
  return instance
end

--- launch grug-far with the given overrides, pre-filling
--- search with current visual selection.
---@param options? grug.far.OptionsOverride partial override of |grug_far.defaultOptions|
---@return grug.far.Instance instance
---@seealso Option types: |grug.far.Options| and |grug-far-instance-api|
function grug_far.with_visual_selection(options)
  local opts = require('grug-far.opts')
  local resolvedOpts = opts.with_defaults(options or {}, opts.getGlobalOptions())
  local visual_selection_info = require('grug-far.utils').get_current_visual_selection_info()
  return grug_far._open_internal(resolvedOpts, { visual_selection_info = visual_selection_info })
end

--- gets the current visual selection as a string array of lines
--- This is provided as a utility for users so they don't have to rewrite
---@param strict? boolean Whether to require visual mode to be active, defaults to False
---@return string[]?
function grug_far.get_current_visual_selection_lines(strict)
  local was_visual = require('grug-far.utils').leaveVisualMode()
  if strict and not was_visual then
    return
  end
  local lines = require('grug-far.utils').getVisualSelectionLines()
  return lines
end

--- gets the current visual selection as a single string
--- This is provided as a utility for users so they don't have to rewrite
---@param strict? boolean Whether to require visual mode to be active to return, defaults to False
---@return string?
function grug_far.get_current_visual_selection(strict)
  local selection_lines = grug_far.get_current_visual_selection_lines(strict)
  return selection_lines and table.concat(selection_lines, '\n')
end

--- gets the current visual selection as a range string
--- useful for passing as a prefill when searching within a buffer
---@param strict? boolean Whether to require visual mode to be active to return, defaults to False
---@return string?
function grug_far.get_current_visual_selection_as_range_str(strict)
  local visual_selection_info = require('grug-far.utils').get_current_visual_selection_info(strict)
  if not visual_selection_info then
    return
  end

  return require('grug-far.utils').get_visual_selection_info_as_str(visual_selection_info)
end

--- gets grug-far instance
--- if instQuery is a string, gets instance with that name
--- if instQuery is a number, gets instance at that buffer (use 0 for current buffer)
--- if instQuery is nil, get any first instance we can get our hands on,
---    with instance in the current tab page preferred
--- if instQuery is non-nil, and no instance found, an error is emitted
---@param instQuery grug.far.InstanceQuery
---@return grug.far.Instance? instance, string? instanceName
---
--- See |grug-far-instance-api|
function grug_far.get_instance(instQuery)
  return require('grug-far.instances').ensure_instance(instQuery)
end

--- toggles visibility of grug-far instance with given instance name or current buffer instance
--- options.instanceName can be used to identify a specific grug-far instance to toggle
---@param options grug.far.OptionsOverride partial override of |grug_far.defaultOptions|
---@seealso Option types: |grug.far.Options|
function grug_far.toggle_instance(options)
  local inst = require('grug-far.instances').get_instance(options.instanceName or 0)
  if not inst then
    grug_far.open(options)
    return
  end

  local win = vim.fn.bufwinid(inst._buf)
  if win == -1 then
    -- toggle it on
    win = grug_far._createWindow(inst._context)
    grug_far._setupWindow(inst._context, win, inst._buf)
    vim.api.nvim_win_set_buf(win, inst._buf)
  else
    -- toggle it off
    vim.api.nvim_win_close(win, true)
  end
end

--- checks if grug-far instance with given name exists
---@param instanceName string
---@return boolean
function grug_far.has_instance(instanceName)
  return require('grug-far.instances').has_instance(instanceName)
end

--- checks if grug-far instance is open
---@param instQuery grug.far.InstanceQuery
---@return boolean
function grug_far.is_instance_open(instQuery)
  local inst = require('grug-far.instances').get_instance(instQuery)
  return inst ~= nil and inst:is_open()
end

--- closes grug-far instance
---@param instQuery grug.far.InstanceQuery
function grug_far.kill_instance(instQuery)
  local inst = require('grug-far.instances').get_instance(instQuery)
  if inst then
    inst:close()
  end
end

--- hides grug-far instance
---@param instQuery grug.far.InstanceQuery
function grug_far.hide_instance(instQuery)
  local inst = require('grug-far.instances').get_instance(instQuery)
  if inst then
    inst:hide()
  end
end

-- deprecated API -----------------------------------------------------------------------------

---@deprecated
--- Note: Deprecated! Use: grug_far.get_instance(...):toggle_flags()
---
--- toggles given list of flags in the current grug-far buffer
---@param flags string[]
---@return boolean[] states
function grug_far.toggle_flags(flags)
  vim.deprecate('toggle_flags(...)', 'get_instance(...):toggle_flags()', 'soon', 'grug-far.nvim')
  return grug_far.get_instance(0):toggle_flags(flags)
end

---@deprecated
--- Note: Deprecated! Use: grug_far.hide_instance(...)
---
--- hides grug-far instance
---@param instQuery grug.far.InstanceQuery
function grug_far.close_instance(instQuery)
  vim.deprecate('close_instance(...)', 'hide_instance(...)', 'soon', 'grug-far.nvim')
  return grug_far.hide_instance(instQuery)
end

---@deprecated
--- Note: Deprecated! Use: grug_far.get_instance(...):open()
---
--- opens grug-far instance with given name (or current buffer instance) if window closed
--- otherwise focuses the window
---@param instQuery grug.far.InstanceQuery
function grug_far.open_instance(instQuery)
  vim.deprecate('open_instance(...)', 'get_instance(...):open()', 'soon', 'grug-far.nvim')
  return grug_far.get_instance(instQuery or 0):open()
end

---@deprecated
--- Note: Deprecated! Use: grug_far.get_instance(...):update_input_values()
---
--- updates grug-far instance with given input prefills
--- operates on grug-far instance with given instance name or current buffer instance (if nil)
--- if clearOld=true is given, the old input values are ignored
---@param instQuery string?
---@param prefills grug.far.Prefills
---@param clearOld boolean
function grug_far.update_instance_prefills(instQuery, prefills, clearOld)
  vim.deprecate(
    'update_instance_prefills(...)',
    'get_instance(...):update_input_values()',
    'soon',
    'grug-far.nvim'
  )
  grug_far.get_instance(instQuery):update_input_values(prefills, clearOld)
end

---@deprecated
--- Note: Deprecated! Use: grug_far.get_instance(...):goto_input()
---
--- moves cursor to the input with the given name
--- operates on grug-far instance with given instance name or current buffer instance
---@param inputName grug.far.InputName
---@param instQuery grug.far.InstanceQuery
function grug_far.goto_input(inputName, instQuery)
  vim.deprecate('goto_input(...)', 'get_instance(...):goto_input()', 'soon', 'grug-far.nvim')
  return grug_far.get_instance(instQuery or 0):goto_input(inputName)
end

---@deprecated
--- Note: Deprecated! Use: grug_far.get_instance(...):goto_first_input()
---
--- moves cursor to the first input
--- operates on grug-far instance with given instance name or current buffer instance
---@param instQuery grug.far.InstanceQuery
function grug_far.goto_first_input(instQuery)
  vim.deprecate(
    'goto_first_input(...)',
    'get_instance(...):goto_first_input()',
    'soon',
    'grug-far.nvim'
  )
  return grug_far.get_instance(instQuery or 0):goto_first_input()
end

---@deprecated
--- Note: Deprecated! Use: grug_far.get_instance(...):goto_next_input()
---
--- moves cursor to the next input
--- operates on grug-far instance with given instance name or current buffer instance
---@param instQuery grug.far.InstanceQuery
function grug_far.goto_next_input(instQuery)
  vim.deprecate(
    'goto_next_input(...)',
    'get_instance(...):goto_next_input()',
    'soon',
    'grug-far.nvim'
  )
  return grug_far.get_instance(instQuery or 0):goto_next_input()
end

---@deprecated
--- Note: Deprecated! Use: grug_far.get_instance(...):goto_prev_input()
---
--- moves cursor to the next input
--- operates on grug-far instance with given instance name or current buffer instance
---@param instQuery grug.far.InstanceQuery
function grug_far.goto_prev_input(instQuery)
  vim.deprecate(
    'goto_prev_input(...)',
    'get_instance(...):goto_prev_input()',
    'soon',
    'grug-far.nvim'
  )
  return grug_far.get_instance(instQuery or 0):goto_prev_input()
end

return grug_far
