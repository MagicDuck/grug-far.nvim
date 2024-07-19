local opts = require('grug-far/opts')
local highlights = require('grug-far/highlights')
local farBuffer = require('grug-far/farBuffer')
local history = require('grug-far/history')
local utils = require('grug-far/utils')

local M = {}

---@type GrugFarOptions
local globalOptions = nil

---@class NamedInstance
---@field buf integer
---@field win? integer
---@field context GrugFarContext

---@type table<string, NamedInstance>
local namedInstances = {}

--- set up grug-far
---@param options? GrugFarOptionsOverride
function M.setup(options)
  if vim.fn.has('nvim-0.9.0') == 0 then
    vim.api.nvim_err_writeln('grug-far is guaranteeed to work on at least nvim-0.9.0')
    return
  end

  globalOptions = opts.with_defaults(options or {}, opts.defaultOptions)
  highlights.setup()
  vim.api.nvim_create_user_command('GrugFar', M.grug_far, {})
end

---@return boolean
local function is_configured()
  return globalOptions ~= nil
end

local contextCount = 0

---@alias GrugFarStatus nil | "success" | "error" | "progress"

---@class ResultLocation
---@field filename string
---@field lnum? integer
---@field col? integer
---@field text? string
---@field end_col? integer

---@class GrugFarInputs
---@field search string
---@field replacement string
---@field filesFilter string
---@field flags string

---@class GrugFarStateAbort
---@field search? fun()
---@field replace? fun()
---@field sync? fun()

---@class GrugFarState
---@field inputs GrugFarInputs
---@field lastInputs? GrugFarInputs
---@field headerRow integer
---@field status? GrugFarStatus
---@field progressCount? integer
---@field stats? { matches: integer, files: integer }
---@field actionMessage? string
---@field resultLocationByExtmarkId { [integer]: ResultLocation }
---@field resultsLastFilename? string
---@field abort GrugFarStateAbort
---@field showRgCommand boolean
---@field bufClosed boolean
---@field highlightResults FileResults
---@field highlightRegions LangRegions

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
---@field instanceName? string
---@field actions GrugFarAction[]

--- generate instance specific context
---@param options GrugFarOptions
---@return GrugFarContext
local function createContext(options)
  contextCount = contextCount + 1
  return {
    count = contextCount,
    options = options,
    namespace = vim.api.nvim_create_namespace('grug-far-namespace'),
    locationsNamespace = vim.api.nvim_create_namespace(''),
    historyHlNamespace = vim.api.nvim_create_namespace(''),
    helpHlNamespace = vim.api.nvim_create_namespace(''),
    augroup = vim.api.nvim_create_augroup('grug-far.nvim-augroup-' .. contextCount, {}),
    extmarkIds = {},
    actions = {},
    state = {
      inputs = {},
      headerRow = 0,
      resultLocationByExtmarkId = {},
      abort = {},
      showRgCommand = false,
      bufClosed = false,
      highlightRegions = {},
      highlightResults = {},
    },
  }
end

---@param context GrugFarContext
---@return integer windowId
local function createWindow(context)
  context.prevWin = vim.api.nvim_get_current_win()
  vim.cmd(context.options.windowCreationCommand)
  local win = vim.api.nvim_get_current_win()

  if context.options.disableBufferLineNumbers then
    vim.api.nvim_set_option_value('number', false, { win = win })
    vim.api.nvim_set_option_value('relativenumber', false, { win = win })
  end

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

    utils.abortTasks(context)
    context.state.bufClosed = true
    if context.instanceName then
      namedInstances[context.instanceName] = nil
    end

    vim.api.nvim_buf_clear_namespace(buf, context.locationsNamespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.namespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.historyHlNamespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.helpHlNamespace, 0, -1)
    vim.api.nvim_del_augroup_by_id(context.augroup)
    require('grug-far/render/treesitter').clear(buf)
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
---@param options? GrugFarOptionsOverride | GrugFarOptions
function M.grug_far(options)
  if not is_configured() then
    print(
      'Please call require("grug-far").setup(...) before executing require("grug-far").grug_far(...)!'
    )
    return
  end

  local resolvedOpts = opts.with_defaults(options or {}, globalOptions)
  if resolvedOpts.instanceName and namedInstances[resolvedOpts.instanceName] then
    print(
      'require("grug-far").grug-far({..., instanceName:...}): A grug-far instance with instanceName="'
        .. resolvedOpts.instanceName
        .. '" already exists!'
    )
    return
  end

  local context = createContext(resolvedOpts)
  local win = createWindow(context)
  local buf = farBuffer.createBuffer(win, context)
  setupCleanup(buf, context)

  if resolvedOpts.instanceName then
    namedInstances[resolvedOpts.instanceName] = { buf = buf, win = win, context = context }
  end
end

--- launch grug-far with the given overrides, pre-filling
--- search with current visual selection. If the visual selection crosses
--- multiple lines, lines are joined
--- (this is because visual selection can contain special chars, so we need to pass
--- --fixed-strings flag to rg. But in that case '\n' is interpreted literally, so we
--- can't use it to separate lines)
---@param options? GrugFarOptionsOverride
function M.with_visual_selection(options)
  local params = opts.with_defaults(options or {}, globalOptions)
  params.prefills.search = utils.getVisualSelectionText()

  local flags = params.prefills.flags or ''
  if not flags:find('%-%-fixed%-strings') then
    flags = (#flags > 0 and flags .. ' ' or flags) .. '--fixed-strings'
  end
  params.prefills.flags = flags

  M.grug_far(params)
end

--- toggles given list of flags in the current grug-far buffer
---@param flags string[]
function M.toggle_flags(flags)
  if #flags == 0 then
    return {}
  end

  local FLAGS_LINE_NO = 6
  local flags_line = vim.fn.getline(FLAGS_LINE_NO)
  local states = {}
  for _, flag in ipairs(flags) do
    local i, j = flags_line:find(' ' .. flag, 1, true)
    if not i then
      i, j = flags_line:find(flag, 1, true)
    end

    if i then
      flags_line = flags_line:sub(1, i - 1) .. flags_line:sub(j + 1, -1)
      table.insert(states, false)
    else
      flags_line = flags_line .. ' ' .. flag
      table.insert(states, true)
    end
  end
  vim.fn.setline(FLAGS_LINE_NO, flags_line)

  return states
end

--- toggles visibility of grug-far instance with given instance name
--- requires options.instanceName to be given in order to identify the grug-far instance to toggle
---@param options GrugFarOptionsOverride
function M.toggle_instance(options)
  if not is_configured() then
    print(
      'Please call require("grug-far").setup(...) before executing require("grug-far").toggle_instance(...)!'
    )
    return
  end

  if not options.instanceName then
    print(
      'require("grug-far").toggle_instance(options): options.instanceName is required! This just needs to be any string you want to use to identify the grug-far instance.'
    )
    return
  end

  if not namedInstances[options.instanceName] then
    M.grug_far(options)
    return
  end

  local inst = namedInstances[options.instanceName]
  if inst.win then
    -- toggle it off
    vim.api.nvim_win_close(inst.win, true)
    inst.win = nil
  else
    -- toggle it on
    inst.win = createWindow(inst.context)
    vim.api.nvim_win_set_buf(inst.win, inst.buf)
  end
end

return M
