local render = require("grug-far/render")

local M = {}

local function with_defaults(options)
  return {
    debounceMs = options.debounceMs or 500
  }
end

local context = nil
-- TODO (sbadragan): do we need some sort of health check?
function M.setup(options)
  context = {
    options = with_defaults(options or {}),
    namespace = vim.api.nvim_create_namespace('grug-far.nvim'),
    extmarkIds = {}
  }

  vim.api.nvim_create_user_command("GrugFar", M.grug_far, {})
end

local function is_configured()
  return context ~= nil
end

function M.grug_far()
  if not is_configured() then
    print('Please call require("grug-far").setup(...) before executing require("grug-far").grug_far(...)!')
    return
  end

  -- create split window
  vim.cmd('vsplit')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Grug Find and Replace')
  vim.api.nvim_win_set_buf(win, buf)

  -- setup renderer
  local function onBufferChange(params)
    render({ buf = params.buf }, context)
  end

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = onBufferChange
  })
end

return M
