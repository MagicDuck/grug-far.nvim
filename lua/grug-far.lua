local my_cool_module = require("grug-far.my_cool_module")

local M = {}

local function with_defaults(options)
  return {
    name = options.name or "John Doe"
  }
end

-- This function is supposed to be called explicitly by users to configure this
-- plugin
function M.setup(options)
  -- avoid setting global values outside of this function. Global state
  -- mutations are hard to debug and test, so having them in a single
  -- function/module makes it easier to reason about all possible changes
  M.options = with_defaults(options or {})

  M.namespace = vim.api.nvim_create_namespace('grug-far.nvim')
  M.extmarkIds = {}

  vim.api.nvim_create_user_command("GrugFar", M.grugFar, {})
end

function M.is_configured()
  return M.options ~= nil
end

function onBufferChange(params)
  local buf = params.buf

  local helpLine = unpack(vim.api.nvim_buf_get_lines(buf, 0, 1, false))
  if #helpLine ~= 0 then
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "" })
  end

  local helpExtmarkPos = M.extmarkIds.help and
    vim.api.nvim_buf_get_extmark_by_id(buf, M.namespace, M.extmarkIds.help, {}) or {}
  if helpExtmarkPos[1] ~= 0 then
    M.extmarkIds.help = vim.api.nvim_buf_set_extmark(buf, M.namespace, 0, 0, {
      id = M.extmarkIds.help,
      end_row = 0,
      end_col = 0,
      virt_text = {
        { "Press g? for help", 'DiagnosticInfo' }
      },
      virt_text_pos = 'overlay'
    })
  end
end

-- public API
function M.grugFar()
  if not M.is_configured() then
    return
  end

  -- create split buffer
  vim.cmd('vsplit')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Grug Find and Replace')
  vim.api.nvim_win_set_buf(win, buf)

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = onBufferChange
  })

  -- add lines
  -- vim.api.nvim_buf_set_lines(buf, 0, 0, false, {
  --   "", -- search
  --   "", -- replace
  --   ""  -- flags
  -- })
  -- add virtual text
  -- vim.api.nvim_buf_set_extmark(buf, M.namespace, 0, 0, {
  --   end_row = 0,
  --   end_col = 0,
  --   virt_text = {
  --     { " --help", 'DiagnosticInfo' }
  --   },
  --   virt_text_pos = 'overlay'
  -- })
  -- vim.api.nvim_buf_set_extmark(buf, M.namespace, 1, 0, {
  --   end_row = 1,
  --   end_col = 0,
  --   virt_lines = {
  --     { { "  Search", 'DiagnosticInfo' } },
  --   },
  --   virt_lines_leftcol = true,
  --   virt_lines_above = true,
  --   right_gravity = false
  -- })
  -- vim.api.nvim_buf_set_extmark(buf, M.namespace, 2, 0, {
  --   end_row = 2,
  --   end_col = 0,
  --   -- TODO (sbadragan): create our own highlight group?
  --   -- virt_lines = { { { "  Search" }, "Comment" } }
  --   -- virt_text_pos = "eol"
  --   virt_lines = {
  --     { { "  Replace", 'DiagnosticInfo' } },
  --   },
  --   virt_lines_leftcol = true,
  --   virt_lines_above = true,
  --   right_gravity = false
  -- })
  -- TODO (sbadragan): update marks on TextChanged, TextChangedI

  -- TODO (sbadragan): remove
  -- try to keep all the heavy logic on pure functions/modules that do not
  -- depend on Neovim APIs. This makes them easy to test
  -- local greeting = my_cool_module.greeting(M.options.name)
  -- print(greeting)
end

M.options = nil
return M
