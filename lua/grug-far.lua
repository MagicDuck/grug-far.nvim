local opts = require('grug-far/opts')
local highlights = require('grug-far/highlights')
local farBuffer = require('grug-far/farBuffer')

local M = {}

---@type GrugFarOptions
local globalOptions = nil

--- set up grug-far
---@param options GrugFarOptions
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
---@field rgResultLine? string
---@field rgColEndIndex? integer

---@class GrugFarInputs
---@field search string
---@field replacement string
---@field filesFilter string
---@field flags string

---@class GrugFarState
---@field inputs GrugFarInputs
---@field lastInputs? GrugFarInputs
---@field headerRow integer
---@field status? GrugFarStatus
---@field progressCount? integer
---@field stats? { matches: integer, files: integer }
---@field actionMessage? string
---@field resultLocationByExtmarkId { [integer]: ResultLocation }
---@field resultsLocations ResultLocation[]
---@field resultsLastFilename? string
---@field abortSearch? fun()

---@class GrugFarContext
---@field count integer
---@field options GrugFarOptions
---@field namespace integer
---@field locationsNamespace integer
---@field augroup integer
---@field extmarkIds {[string]: integer}
---@field state GrugFarState
---@field prevWin? integer

--- generate instance specific context
---@param options GrugFarOptions
---@return GrugFarContext
local function createContext(options)
  contextCount = contextCount + 1
  return {
    count = contextCount,
    options = options,
    namespace = vim.api.nvim_create_namespace('grug-far'),
    locationsNamespace = vim.api.nvim_create_namespace(''),
    augroup = vim.api.nvim_create_augroup('grug-far.nvim-augroup-' .. contextCount, {}),
    extmarkIds = {},
    state = {
      inputs = {},
      headerRow = 0,
      resultsLocations = {},
      resultLocationByExtmarkId = {},
    },
  }
end

---@param context GrugFarContext
---@return integer windowId
local function createWindow(context)
  context.prevWin = vim.api.nvim_get_current_win()
  vim.cmd('vsplit')
  local win = vim.api.nvim_get_current_win()

  if context.options.disableBufferLineNumbers then
    vim.api.nvim_win_set_option(win, 'number', false)
    vim.api.nvim_win_set_option(win, 'relativenumber', false)
  end

  return win
end

---@param buf integer
---@param context GrugFarContext
local function setupCleanup(buf, context)
  local function onBufDelete()
    vim.api.nvim_buf_clear_namespace(buf, context.locationsNamespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.namespace, 0, -1)
    vim.api.nvim_del_augroup_by_id(context.augroup)
  end

  vim.api.nvim_create_autocmd({ 'BufDelete' }, {
    group = context.augroup,
    buffer = buf,
    callback = onBufDelete,
  })
end

--- launch grug-far with the given overrides
---@param options GrugFarOptions
function M.grug_far(options)
  if not is_configured() then
    print(
      'Please call require("grug-far").setup(...) before executing require("grug-far").grug_far(...)!'
    )
    return
  end

  local context = createContext(opts.with_defaults(options or {}, globalOptions))
  local win = createWindow(context)
  local buf = farBuffer.createBuffer(win, context)
  setupCleanup(buf, context)
end

return M
