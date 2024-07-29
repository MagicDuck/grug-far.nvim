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
---@field context GrugFarContext

---@type table<string, NamedInstance>
local namedInstances = {}

---@return boolean
local function is_configured()
  return globalOptions ~= nil
end

--- set up grug-far
---@param options? GrugFarOptionsOverride
function M.setup(options)
  if vim.fn.has('nvim-0.9.5') == 0 then
    vim.api.nvim_err_writeln('grug-far is guaranteeed to work on at least nvim-0.9.5')
    return
  end

  globalOptions = opts.with_defaults(options or {}, opts.defaultOptions)
  highlights.setup()
  vim.api.nvim_create_user_command('GrugFar', function(params)
    local is_visual = params.range > 0
    local resolvedOpts = opts.with_defaults({}, globalOptions)
    if params.mods and #params.mods > 0 then
      resolvedOpts.windowCreationCommand = params.mods .. ' split'
    end
    M._grug_far_internal(resolvedOpts, { is_visual = is_visual })
  end, { nargs = 0, range = true })
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
---@field paths string

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

  vim.api.nvim_set_option_value('wrap', context.options.wrap, { win = win })

  vim.api.nvim_set_option_value('foldmethod', 'expr', { win = win })
  vim.api.nvim_set_option_value(
    'foldexpr',
    'v:lua.require("grug-far/fold").getFoldLevel(v:lnum)',
    { win = win }
  )
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
    if context.options.instanceName then
      namedInstances[context.options.instanceName] = nil
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
---@param options? GrugFarOptionsOverride
function M.grug_far(options)
  local resolvedOpts = opts.with_defaults(options or {}, globalOptions)
  local is_visual = resolvedOpts.ignoreVisualSelection and false
    or vim.fn.mode():lower():find('v') ~= nil
  if is_visual then
    -- needed to make visual selection work
    vim.cmd([[normal! vv]])
  end

  M._grug_far_internal(resolvedOpts, { is_visual = is_visual })
end

--- launch grug-far with the given options and params
---@param options GrugFarOptions
---@param params { is_visual: boolean }
function M._grug_far_internal(options, params)
  if not is_configured() then
    print('Please call require("grug-far").setup(...) before executing grug-far API!')
    return
  end

  if options.instanceName and namedInstances[options.instanceName] then
    print(
      'require("grug-far").grug-far({..., instanceName:...}): A grug-far instance with instanceName="'
        .. options.instanceName
        .. '" already exists!'
    )
    return
  end

  if params.is_visual then
    --- search with current visual selection. If the visual selection crosses
    --- multiple lines, lines are joined
    --- (this is because visual selection can contain special chars, so we need to pass
    --- --fixed-strings flag to rg. But in that case '\n' is interpreted literally, so we
    --- can't use it to separate lines)

    options.prefills.search = utils.getVisualSelectionText()
    local flags = options.prefills.flags or ''
    if not flags:find('%-%-fixed%-strings') then
      flags = (#flags > 0 and flags .. ' ' or flags) .. '--fixed-strings'
    end
    options.prefills.flags = flags
  end

  local context = createContext(options)
  local win = createWindow(context)
  local buf = farBuffer.createBuffer(win, context)
  setupCleanup(buf, context)

  if options.instanceName then
    namedInstances[options.instanceName] = { buf = buf, context = context }
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
  local resolvedOpts = opts.with_defaults(options or {}, globalOptions)
  M._grug_far_internal(resolvedOpts, { is_visual = true })
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

return M
