local opts = require('grug-far.opts')
local highlights = require('grug-far.highlights')
local farBuffer = require('grug-far.farBuffer')
local history = require('grug-far.history')
local utils = require('grug-far.utils')
local tasks = require('grug-far.tasks')
local close = require('grug-far.actions.close')
local engine = require('grug-far.engine')
local replacementInterpreter = require('grug-far.replacementInterpreter')
local fold = require('grug-far.fold')
local inputs = require('grug-far.inputs')
local fileIconsProvider = require('grug-far.fileIconsProvider')

local M = {}

---@type GrugFarOptions
local globalOptions = nil

---@class NamedInstance
---@field buf integer
---@field context GrugFarContext

---@type table<string, NamedInstance>
local namedInstances = {}

---@return boolean
local function is_configured()
  return globalOptions ~= nil
end

local function ensure_configured()
  if not is_configured() then
    error('Please call require("grug-far").setup(...) beforehand!')
  end
end

---@param instanceName string
local function ensure_instance_name(instanceName)
  if not instanceName then
    error(
      'instanceName is required! This just needs to be any string you want to use to identify the grug-far instance.'
    )
  end
end

---@param instanceName string
local function ensure_instance(instanceName)
  ensure_instance_name(instanceName)
  local inst = namedInstances[instanceName]
  if not inst then
    error('No such grug-far instance: ' .. instanceName)
  end

  return inst
end

-- note: unfortunately has to be global so it can be passed to command complete= opt
-- selene: allow(unused_variable)
function GrugFarCompleteEngine()
  return table.concat(vim.fn.keys(opts.defaultOptions.engines), '\n')
end

--- set up grug-far
---@param options? GrugFarOptionsOverride
function M.setup(options)
  if vim.fn.has('nvim-0.10.0') == 0 then
    vim.api.nvim_err_writeln('grug-far needs nvim >= 0.10.0')
    return
  end

  globalOptions = opts.with_defaults(options or {}, opts.defaultOptions)
  highlights.setup()
  vim.api.nvim_create_user_command('GrugFar', function(params)
    local engineParam = params.fargs[1]
    local visual_selection_lines
    if params.range > 0 then
      visual_selection_lines = M.get_current_visual_selection_lines()
    end
    local resolvedOpts = opts.with_defaults({ engine = engineParam }, globalOptions)
    if params.mods and #params.mods > 0 then
      resolvedOpts.windowCreationCommand = params.mods .. ' split'
    end
    M._open_internal(resolvedOpts, { visual_selection_lines = visual_selection_lines })
  end, {
    nargs = '?',
    range = true,
    complete = 'custom,v:lua.GrugFarCompleteEngine',
  })
end

local contextCount = 0

---@alias GrugFarStatus nil | "success" | "error" | "progress"

---@class ResultLocation
---@field filename string
---@field lnum? integer
---@field col? integer
---@field text? string
---@field end_col? integer
---@field sign? ResultHighlightSign
---@field count? integer

---@class GrugFarInputs
---@field search? string
---@field rules? string
---@field replacement string
---@field filesFilter string
---@field flags string
---@field paths string

---@class GrugFarState
---@field inputs GrugFarInputs
---@field lastInputs? GrugFarInputs
---@field headerRow integer
---@field status? GrugFarStatus
---@field progressCount? integer
---@field stats? { matches: integer, files: integer }
---@field actionMessage? string
---@field resultLocationByExtmarkId { [integer]: ResultLocation }
---@field resultMatchLineCount integer
---@field resultsLastFilename? string
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
---@field winDefaultOpts table<string, any>

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
      headerRow = 0,
      resultLocationByExtmarkId = {},
      resultMatchLineCount = 0,
      tasks = {},
      showSearchCommand = false,
      bufClosed = false,
      highlightRegions = {},
      highlightResults = {},
      normalModeSearch = options.normalModeSearch,
      searchDisabled = false,
      previousInputValues = {},
    },
    winDefaultOpts = {},
  }
end

--- sets window option, storing previous "default" value in winDefaultOpts
--- those are used when we split off new windows and don't want to inherit those opts
---@param context GrugFarContext
---@param win integer
---@param name string
---@param value any
local function setWinOption(context, win, name, value)
  context.winDefaultOpts[name] = vim.api.nvim_get_option_value(name, { win = win })
  vim.api.nvim_set_option_value(name, value, { win = win })
end

---@param context GrugFarContext
---@return integer windowId
local function createWindow(context)
  context.prevWin = vim.api.nvim_get_current_win()
  local prevBuf = vim.api.nvim_win_get_buf(context.prevWin)
  context.prevBufName = vim.api.nvim_buf_get_name(prevBuf)
  context.prevBufFiletype = vim.bo[prevBuf].filetype

  vim.cmd(context.options.windowCreationCommand)
  local win = vim.api.nvim_get_current_win()

  if context.options.disableBufferLineNumbers then
    setWinOption(context, win, 'number', false)
    setWinOption(context, win, 'relativenumber', false)
  end

  setWinOption(context, win, 'wrap', context.options.wrap)

  fold.setup(context, win)

  return win
end

---@param buf integer
---@param context GrugFarContext
local function setupCleanup(buf, context)
  local function cleanup()
    local autoSave = context.options.history.autoSave
    if autoSave.enabled and autoSave.onBufDelete then
      history.addHistoryEntry(context)
    end

    tasks.abortAndFinishAllTasks(context)
    context.state.bufClosed = true
    if context.options.instanceName then
      namedInstances[context.options.instanceName] = nil
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
  ensure_configured()
  local resolvedOpts = opts.with_defaults(options or {}, globalOptions)
  local visual_selection_lines
  if not resolvedOpts.ignoreVisualSelection then
    visual_selection_lines = M.get_current_visual_selection_lines(true)
  end

  return M._open_internal(resolvedOpts, { visual_selection_lines = visual_selection_lines })
end

--- launch grug-far with the given options and params
---@param options GrugFarOptions
---@param params { visual_selection_lines: string[]? }
---@return string instanceName
function M._open_internal(options, params)
  if options.instanceName and namedInstances[options.instanceName] then
    error('A grug-far instance with instanceName="' .. options.instanceName .. '" already exists!')
  end

  local context = createContext(options)
  if not options.instanceName then
    options.instanceName = '__grug_far_instance__' .. context.count
  end
  if params.visual_selection_lines then
    options.prefills = context.engine.getInputPrefillsForVisualSelection(
      params.visual_selection_lines,
      options.prefills
    )
  end

  local win = createWindow(context)
  local buf = farBuffer.createBuffer(win, context)
  setupCleanup(buf, context)
  namedInstances[options.instanceName] = { buf = buf, context = context }

  return options.instanceName
end

--- returns instance name associated with given buf number
--- if given buf number is 0, returns instance for current buffer
---@param buf integer (same argument as for bufnr())
---@return string?
function M.get_instance_name_by_buf(buf)
  local bufnr = vim.fn.bufnr(buf)
  for instanceName, instance in pairs(namedInstances) do
    if instance.buf == bufnr then
      return instanceName
    end
  end
  return nil
end

--- toggles given list of flags in the current grug-far buffer
---@param flags string[]
function M.toggle_flags(flags)
  if #flags == 0 then
    return {}
  end

  local instanceName = M.get_instance_name_by_buf(0)
  if not instanceName then
    return
  end

  local instance = namedInstances[instanceName]

  local flags_value = instance.context.state.inputs.flags
  local states = {}
  for _, flag in ipairs(flags) do
    local i, j = flags_value:find(' ' .. flag, 1, true)
    if not i then
      i, j = flags_value:find(flag, 1, true)
    end

    if i then
      flags_value = flags_value:sub(1, i - 1) .. flags_value:sub(j + 1, -1)
      table.insert(states, false)
    else
      flags_value = flags_value .. ' ' .. flag
      table.insert(states, true)
    end
  end

  inputs.fill(instance.context, instance.buf, { flags = flags_value }, false)

  return states
end

--- toggles visibility of grug-far instance with given instance name
--- requires options.instanceName to be given in order to identify the grug-far instance to toggle
---@param options GrugFarOptionsOverride
function M.toggle_instance(options)
  ensure_configured()
  ensure_instance_name(options.instanceName)

  local inst = namedInstances[options.instanceName]
  if not inst then
    M.open(options)
    return
  end

  local win = vim.fn.bufwinid(inst.buf)
  if win == -1 then
    -- toggle it on
    win = createWindow(inst.context)
    vim.api.nvim_win_set_buf(win, inst.buf)
  else
    -- toggle it off
    vim.api.nvim_win_close(win, true)
  end
end

--- checks if grug-far instance with given name exists
---@param instanceName string
---@return boolean
function M.has_instance(instanceName)
  return not not namedInstances[instanceName]
end

--- checks if grug-far instance with given name is open
---@param instanceName string
---@return boolean
function M.is_instance_open(instanceName)
  local inst = namedInstances[instanceName]
  if not inst then
    return false
  end

  local win = vim.fn.bufwinid(inst.buf)
  return win ~= -1
end

--- closes grug-far instance with given name
---@param instanceName string
function M.kill_instance(instanceName)
  ensure_instance_name(instanceName)
  local inst = namedInstances[instanceName]
  if inst then
    close({ context = inst.context, buf = inst.buf })
  end
end

--- hides grug-far instance with given name
---@param instanceName string
function M.close_instance(instanceName)
  ensure_instance_name(instanceName)
  local inst = namedInstances[instanceName]
  if inst then
    local win = vim.fn.bufwinid(inst.buf)
    if win ~= -1 then
      vim.api.nvim_win_close(win, true)
    end
  end
end

--- opens grug-far instance with given name if window closed
--- otherwise focuses the window
---@param instanceName string
function M.open_instance(instanceName)
  ensure_configured()
  local inst = ensure_instance(instanceName)

  local win = vim.fn.bufwinid(inst.buf)
  if win == -1 then
    -- toggle it on
    win = createWindow(inst.context)
    vim.api.nvim_win_set_buf(win, inst.buf)
  else
    -- focus it
    vim.api.nvim_set_current_win(win)
  end
end

--- updates grug-far instance with given input prefills
--- if clearOld=true is given, the old input values are ignored
---@param instanceName string
---@param prefills GrugFarPrefills
---@param clearOld boolean
function M.update_instance_prefills(instanceName, prefills, clearOld)
  ensure_configured()
  local inst = ensure_instance(instanceName)

  vim.schedule(function()
    inputs.fill(inst.context, inst.buf, prefills, clearOld)
  end)
end

--- launch grug-far with the given overrides, pre-filling
--- search with current visual selection.
---@param options? GrugFarOptionsOverride
function M.with_visual_selection(options)
  ensure_configured()

  local resolvedOpts = opts.with_defaults(options or {}, globalOptions)
  local visual_selection_lines = M.get_current_visual_selection_lines()
  return M._open_internal(resolvedOpts, { visual_selection_lines = visual_selection_lines })
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
  return utils.getVisualSelectionLines()
end

--- gets the current visual selection as a single string
--- This is provided as a utility for users so they don't have to rewrite
---@param strict? boolean Whether to require visual mode to be active to return, defaults to False
---@return string?
function M.get_current_visual_selection(strict)
  local selection_lines = M.get_current_visual_selection_lines(strict)
  return selection_lines and table.concat(selection_lines, '\n')
end

---@deprecated use open(same options) instead
--- launch grug-far with the given overrides
---@param options? GrugFarOptionsOverride
---@return string instanceName
function M.grug_far(options)
  return M.open(options)
end

return M
