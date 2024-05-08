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

local function createContext()
  return {
    options = options,
    namespace = namespace,
    locationsNamespace = vim.api.nvim_create_namespace(''),
    extmarkIds = {},
    state = {
      isFirstRender = true,
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

function M.grug_far()
  if not is_configured() then
    print('Please call require("grug-far").setup(...) before executing require("grug-far").grug_far(...)!')
    return
  end

  local context = createContext()
  local win = createWindow(context)
  farBuffer.createBuffer(win, context)
end

return M
