local opts = require("grug-far/opts")
local highlights = require("grug-far/highlights")
local farBuffer = require("grug-far/farBuffer")

local M = {}

local options = nil
local namespace = nil
function M.setup(user_opts)
  options = opts.with_defaults(user_opts or {})
  namespace = vim.api.nvim_create_namespace('grug-far')
  highlights.setup()
  vim.api.nvim_create_user_command("GrugFar", M.grug_far, {})
end

local function is_configured()
  return options ~= nil
end

local contextCount = 0
local function createContext()
  contextCount = contextCount + 1
  return {
    count = contextCount,
    options = options,
    namespace = namespace,
    locationsNamespace = vim.api.nvim_create_namespace(''),
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
  end

  vim.api.nvim_create_autocmd({ 'BufDelete' }, {
    buffer = buf,
    callback = onBufDelete
  })
end

function M.grug_far()
  if not is_configured() then
    print('Please call require("grug-far").setup(...) before executing require("grug-far").grug_far(...)!')
    return
  end

  local context = createContext()
  local win = createWindow(context)
  local buf = farBuffer.createBuffer(win, context)
  setupCleanup(buf, context)
end

return M
