local instances = require('grug-far.instances')
local opts = require('grug-far.opts')
local highlights = require('grug-far.highlights')
local farBuffer = require('grug-far.farBuffer')
local history = require('grug-far.history')
local utils = require('grug-far.utils')
local tasks = require('grug-far.tasks')
local engine = require('grug-far.engine')
local replacementInterpreter = require('grug-far.replacementInterpreter')
local fold = require('grug-far.fold')
local fileIconsProvider = require('grug-far.fileIconsProvider')

local M = {}

local contextCount = 0

highlights.setup()

--- set up grug-far
--- sets global options, which can also be configured through vim.g.grug_far
---@param options? GrugFarOptionsOverride
function M.setup(options)
  opts.setGlobalOptionsOverride(options)
end

---@alias GrugFarStatus nil | "success" | "error" | "progress"

---@class ResultLocation: SourceLocation
---@field count? integer
---@field max_line_number_length? integer
---@field max_column_number_length? integer
---@field is_context? boolean

---@alias GrugFarInputName "search" | "rules" | "replacement" | "filesFilter" | "flags" | "paths"

---@class GrugFarInputs
---@field [GrugFarInputName] string?

---@class GrugFarState
---@field lastInputs? GrugFarInputs
---@field status? GrugFarStatus
---@field progressCount? integer
---@field stats? { matches: integer, files: integer }
---@field actionMessage? string
---@field resultLocationByExtmarkId { [integer]: ResultLocation }
---@field resultMatchLineCount integer
---@field lastCursorLocation { loc:  ResultLocation, row: integer, markId: integer }
---@field tasks GrugFarTask[]
---@field showSearchCommand boolean
---@field bufClosed boolean
---@field highlightResults FileResults
---@field highlightRegions LangRegions
---@field normalModeSearch boolean
---@field searchDisabled boolean
---@field previousInputValues { [string]: string }

---@class GrugFarAction
---@field text string
---@field keymap KeymapDef
---@field description? string
---@field action? fun()

---@class GrugFarContext
---@field count integer
---@field options GrugFarOptions
---@field namespace integer
---@field locationsNamespace integer
---@field resultListNamespace integer
---@field historyHlNamespace integer
---@field helpHlNamespace integer
---@field augroup integer
---@field extmarkIds {[string]: integer}
---@field state GrugFarState
---@field prevWin? integer
---@field prevBufName? string
---@field prevBufFiletype? string
---@field actions GrugFarAction[]
---@field engine GrugFarEngine
---@field replacementInterpreter? GrugFarReplacementInterpreter
---@field fileIconsProvider? FileIconsProvider

---@class VisualSelectionInfo
---@field file_name string
---@field lines string[]
---@field start_col integer
---@field start_row integer
---@field end_col integer
---@field end_row integer

--- generate instance specific context
---@param options GrugFarOptions
---@return GrugFarContext
local function createContext(options)
  contextCount = contextCount + 1
  return {
    count = contextCount,
    options = options,
    engine = engine.getEngine(options.engine),
    replacementInterpreter = replacementInterpreter.getReplacementInterpreter(
      options.replacementInterpreter
    ),
    namespace = vim.api.nvim_create_namespace('grug-far-namespace'),
    locationsNamespace = vim.api.nvim_create_namespace(''),
    resultListNamespace = vim.api.nvim_create_namespace(''),
    historyHlNamespace = vim.api.nvim_create_namespace(''),
    helpHlNamespace = vim.api.nvim_create_namespace(''),
    augroup = vim.api.nvim_create_augroup('grug-far.nvim-augroup-' .. contextCount, {}),
    extmarkIds = {},
    actions = {},
    fileIconsProvider = options.icons.enabled and fileIconsProvider.getProvider(
      options.icons.fileIconsProvider
    ) or nil,
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
end

---@param context GrugFarContext
---@return integer windowId
function M._createWindow(context)
  context.prevWin = vim.api.nvim_get_current_win()
  local prevBuf = vim.api.nvim_win_get_buf(context.prevWin)
  context.prevBufName = vim.api.nvim_buf_get_name(prevBuf)
  context.prevBufFiletype = vim.bo[prevBuf].filetype

  vim.cmd(context.options.windowCreationCommand)
  local win = vim.api.nvim_get_current_win()

  return win
end

---@param context GrugFarContext
---@param win integer
---@param buf integer
function M._setupWindow(context, win, buf)
  if context.options.disableBufferLineNumbers then
    vim.wo[win][0].number = false
    vim.wo[win][0].relativenumber = false
  end

  vim.wo[win][0].wrap = context.options.wrap
  vim.wo[win][0].breakindent = true
  vim.wo[win][0].breakindentopt = context.options.breakindentopt
  if opts.shouldConceal(context.options) then
    vim.wo[win][0].conceallevel = 1
  end

  fold.setup(context, win, buf)
end

---@param buf integer
---@param context GrugFarContext
local function setupCleanup(buf, context)
  local function cleanup()
    local autoSave = context.options.history.autoSave
    if autoSave.enabled and autoSave.onBufDelete then
      history.addHistoryEntry(context, buf)
    end

    tasks.abortAndFinishAllTasks(context)
    context.state.bufClosed = true
    local _, instanceName = instances.get_instance_by_buf(buf)
    if instanceName then
      instances.remove_instance(context.options.instanceName)
    end

    vim.api.nvim_buf_clear_namespace(buf, context.locationsNamespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.namespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.historyHlNamespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.helpHlNamespace, 0, -1)
    vim.api.nvim_del_augroup_by_id(context.augroup)
    require('grug-far.render.treesitter').clear(buf)
    fold.cleanup(context)
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
---@param options? GrugFarOptionsOverride
---@return string instanceName
function M.open(options)
  local resolvedOpts = opts.with_defaults(options or {}, opts.getGlobalOptions())
  local visual_selection_info
  if resolvedOpts.visualSelectionUsage ~= 'ignore' then
    visual_selection_info = utils.get_current_visual_selection_info(true)
  end

  return M._open_internal(resolvedOpts, { visual_selection_info = visual_selection_info })
end

--- launch grug-far with the given options and params
---@param options GrugFarOptions
---@param params { visual_selection_info: VisualSelectionInfo? }
---@return string instanceName
function M._open_internal(options, params)
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

  local win = M._createWindow(context)
  local buf = farBuffer.createBuffer(win, context)
  M._setupWindow(context, win, buf)
  setupCleanup(buf, context)
  instances.add_instance(options.instanceName, instances.new(context, buf))

  return options.instanceName
end

--- launch grug-far with the given overrides, pre-filling
--- search with current visual selection.
---@param options? GrugFarOptionsOverride
function M.with_visual_selection(options)
  local resolvedOpts = opts.with_defaults(options or {}, opts.getGlobalOptions())
  local visual_selection_info = utils.get_current_visual_selection_info()
  return M._open_internal(resolvedOpts, { visual_selection_info = visual_selection_info })
end

--- gets the current visual selection as a string array of lines
--- This is provided as a utility for users so they don't have to rewrite
---@param strict? boolean Whether to require visual mode to be active, defaults to False
---@return string[]?
function M.get_current_visual_selection_lines(strict)
  local was_visual = utils.leaveVisualMode()
  if strict and not was_visual then
    return
  end
  local lines = utils.getVisualSelectionLines()
  return lines
end

--- gets the current visual selection as a single string
--- This is provided as a utility for users so they don't have to rewrite
---@param strict? boolean Whether to require visual mode to be active to return, defaults to False
---@return string?
function M.get_current_visual_selection(strict)
  local selection_lines = M.get_current_visual_selection_lines(strict)
  return selection_lines and table.concat(selection_lines, '\n')
end

--- gets the current visual selection as a range string
--- useful for passing as a prefill when searching within a buffer
---@param strict? boolean Whether to require visual mode to be active to return, defaults to False
---@return string?
function M.get_current_visual_selection_as_range_str(strict)
  local visual_selection_info = utils.get_current_visual_selection_info(strict)
  if not visual_selection_info then
    return
  end

  return utils.get_visual_selection_info_as_str(visual_selection_info)
end

--- returns grug-far instance.
--- if instQuery is a string, gets instance with that name
--- if instQuery is a number, gets instance at that buffer (use 0 for current buffer)
--- if instQuery is nil, get any first instance we can get our hands on
--- if instQuery is non-nil, and no instance found, an error is emitted
---@param instQuery GrugFarInstanceQuery
---@return GrugFarInstance instance, string instanceName
function M.get_instance(instQuery)
  return instances.ensure_instance(instQuery)
end

--- toggles visibility of grug-far instance with given instance name or current buffer instance
--- options.instanceName can be used to identify a specific grug-far instance to toggle
---@param options GrugFarOptionsOverride
function M.toggle_instance(options)
  local inst = instances.get_instance(options.instanceName or 0)
  if not inst then
    M.open(options)
    return
  end

  local win = vim.fn.bufwinid(inst._buf)
  if win == -1 then
    -- toggle it on
    win = M._createWindow(inst._context)
    M._setupWindow(inst._context, win, inst._buf)
    vim.api.nvim_win_set_buf(win, inst._buf)
  else
    -- toggle it off
    vim.api.nvim_win_close(win, true)
  end
end

--- checks if grug-far instance with given name exists
---@param instanceName string
---@return boolean
function M.has_instance(instanceName)
  return instances.has_instance(instanceName)
end

--- checks if grug-far instance is open
---@param instQuery GrugFarInstanceQuery
---@return boolean
function M.is_instance_open(instQuery)
  local inst = instances.get_instance(instQuery)
  return inst ~= nil and inst:is_open()
end

--- closes grug-far instance
---@param instQuery GrugFarInstanceQuery
function M.kill_instance(instQuery)
  local inst = instances.get_instance(instQuery)
  if inst then
    inst:close()
  end
end

--- hides grug-far instance
---@param instQuery GrugFarInstanceQuery
function M.hide_instance(instQuery)
  local inst = instances.get_instance(instQuery)
  if inst then
    inst:hide()
  end
end

--- deprecated API -----------------------------------------------------------------------------

---@deprecated
--- toggles given list of flags in the current grug-far buffer
---@param flags string[]
---@return boolean[] states
function M.toggle_flags(flags)
  vim.deprecate('toggle_flags(...)', 'get_instance(...):toggle_flags()', 'soon', 'grug-far.nvim')
  return M.get_instance(0):toggle_flags(flags)
end

---@deprecated
--- hides grug-far instance
---@param instQuery GrugFarInstanceQuery
function M.close_instance(instQuery)
  vim.deprecate('close_instance(...)', 'hide_instance(...)', 'soon', 'grug-far.nvim')
  return M.hide_instance(instQuery)
end

---@deprecated
--- opens grug-far instance with given name (or current buffer instance) if window closed
--- otherwise focuses the window
---@param instQuery GrugFarInstanceQuery
function M.open_instance(instQuery)
  vim.deprecate('open_instance(...)', 'get_instance(...):open()', 'soon', 'grug-far.nvim')
  return M.get_instance(instQuery or 0):open()
end

---@deprecated
--- updates grug-far instance with given input prefills
--- operates on grug-far instance with given instance name or current buffer instance (if nil)
--- if clearOld=true is given, the old input values are ignored
---@param instQuery string?
---@param prefills GrugFarPrefills
---@param clearOld boolean
function M.update_instance_prefills(instQuery, prefills, clearOld)
  vim.deprecate(
    'update_instance_prefills(...)',
    'get_instance(...):update_input_values()',
    'soon',
    'grug-far.nvim'
  )
  M.get_instance(instQuery):update_input_values(prefills, clearOld)
end

---@deprecated
--- moves cursor to the input with the given name
--- operates on grug-far instance with given instance name or current buffer instance
---@param inputName GrugFarInputName
---@param instQuery GrugFarInstanceQuery
function M.goto_input(inputName, instQuery)
  vim.deprecate('goto_input(...)', 'get_instance(...):goto_input()', 'soon', 'grug-far.nvim')
  return M.get_instance(instQuery or 0):goto_input(inputName)
end

---@deprecated
--- moves cursor to the first input
--- operates on grug-far instance with given instance name or current buffer instance
---@param instQuery GrugFarInstanceQuery
function M.goto_first_input(instQuery)
  vim.deprecate(
    'goto_first_input(...)',
    'get_instance(...):goto_first_input()',
    'soon',
    'grug-far.nvim'
  )
  return M.get_instance(instQuery or 0):goto_first_input()
end

---@deprecated
--- moves cursor to the next input
--- operates on grug-far instance with given instance name or current buffer instance
---@param instQuery GrugFarInstanceQuery
function M.goto_next_input(instQuery)
  vim.deprecate(
    'goto_next_input(...)',
    'get_instance(...):goto_next_input()',
    'soon',
    'grug-far.nvim'
  )
  return M.get_instance(instQuery or 0):goto_next_input()
end

---@deprecated
--- moves cursor to the next input
--- operates on grug-far instance with given instance name or current buffer instance
---@param instQuery GrugFarInstanceQuery
function M.goto_prev_input(instQuery)
  vim.deprecate(
    'goto_prev_input(...)',
    'get_instance(...):goto_prev_input()',
    'soon',
    'grug-far.nvim'
  )
  return M.get_instance(instQuery or 0):goto_prev_input()
end

return M
