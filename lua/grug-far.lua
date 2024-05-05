local render = require("grug-far/render")

local M = {}

local function with_defaults(options)
  return vim.tbl_deep_extend('force', {
    debounceMs = 500,
    highlights = {
      resultsMatch = '@diff.delta',
      resultsPath = '@string.special.path',
      resultsLineNo = 'Number',
      resultsLineColumn = 'Number',
      helpHeader = 'WarningMsg'
    }
  }, options)
end

local options = nil
local namespace = nil
-- TODO (sbadragan): do we need some sort of health check?
function M.setup(opts)
  options = with_defaults(opts or {})
  namespace = vim.api.nvim_create_namespace('grug-far.nvim')
  vim.api.nvim_create_user_command("GrugFar", M.grug_far, {})
end

local function is_configured()
  return options ~= nil
end

local function createContext()
  return {
    options = options,
    namespace = namespace,
    extmarkIds = {},
    state = {
      isFirstRender = true
    }
  }
end

function M.grug_far()
  if not is_configured() then
    print('Please call require("grug-far").setup(...) before executing require("grug-far").grug_far(...)!')
    return
  end

  local context = createContext();

  -- create split window
  vim.cmd('vsplit')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf, 'Grug Find and Replace')
  vim.api.nvim_win_set_buf(win, buf)
  vim.cmd('startinsert!')

  -- setup renderer
  local function onBufferChange(params)
    render({ buf = params.buf }, context)

    if context.state.isFirstRender then
      context.state.isFirstRender = false
      vim.api.nvim_win_set_cursor(win, { 2, 0 })
    end
  end

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = onBufferChange
  })

  -- TODO (sbadragan): just a test of writing a file, it worked
  -- The idea is to process files with rg --passthrough -N <search> -r <replace> <filepath>
  -- then get the output and write it out to the file using libuv
  -- local f = io.open(
  --   './reactUi/src/pages/IncidentManagement/IncidentDetails/components/PanelDisplayComponents/useIncidentPanelToggle.js',
  --   'w+')
  -- if f then
  --   f:write("stuff")
  --   f:close()
  -- end
end

return M
