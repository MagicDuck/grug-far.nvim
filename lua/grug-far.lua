local opts = require("grug-far/opts")
local highlights = require("grug-far/highlights")
local farBuffer = require("grug-far/farBuffer")

local M = {}

local globalOptions = nil
local namespace = nil
function M.setup(options)
  globalOptions = opts.with_defaults(options or {}, opts.defaultOptions)
  namespace = vim.api.nvim_create_namespace('grug-far')
  highlights.setup()
  vim.api.nvim_create_user_command("GrugFar", M.grug_far, {})
end

local function is_configured()
  return globalOptions ~= nil
end

local contextCount = 0
local function createContext(options)
  contextCount = contextCount + 1
  return {
    count = contextCount,
    options = options,
    namespace = namespace,
    locationsNamespace = vim.api.nvim_create_namespace(''),
    augroup = vim.api.nvim_create_augroup('grug-far.nvim-augroup-' .. contextCount, {}),
    extmarkIds = {},
    state = {
      inputs = {}
    }
  }
end

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

local function setupCleanup(buf, context)
  local function onBufDelete()
    vim.api.nvim_buf_clear_namespace(buf, context.locationsNamespace, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, context.namespace, 0, -1)
    vim.api.nvim_del_augroup_by_id(context.augroup)
  end

  vim.api.nvim_create_autocmd({ 'BufDelete' }, {
    group = context.augroup,
    buffer = buf,
    callback = onBufDelete
  })
end

function M.grug_far(options)
  if not is_configured() then
    print('Please call require("grug-far").setup(...) before executing require("grug-far").grug_far(...)!')
    return
  end

  local context = createContext(opts.with_defaults(options or {}, globalOptions))
  local win = createWindow(context)
  local buf = farBuffer.createBuffer(win, context)
  setupCleanup(buf, context)
end

return M
