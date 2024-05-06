local render = require("grug-far/render")

local M = {}

local function setBufKeymap(buf, modes, desc, lhs, callback)
  for i = 1, #modes do
    local mode = modes:sub(i, i)
    vim.api.nvim_buf_set_keymap(buf, mode, lhs, '',
      { noremap = true, desc = desc, callback = callback })
  end
end

local function setupKeymap(buf, options)
  local keymaps = options.keymaps
  if keymaps.replace then
    setBufKeymap(buf, 'niv', 'Grug Far: apply replacements', keymaps.replace, function()
      P('sttufff----------')
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
    end)
  end
end

local function setupRenderer(win, buf, context)
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
end

function M.createBuffer(win, context)
  local buf = vim.api.nvim_create_buf(true, true)
  -- TODO (sbadragan): update with search?
  vim.api.nvim_buf_set_name(buf, 'Grug Find and Replace')
  setupKeymap(buf, context.options)

  vim.api.nvim_win_set_buf(win, buf)
  vim.cmd('startinsert!')

  setupRenderer(win, buf, context)

  -- TODO (sbadragan): refactor, create a separate "actions" that executes stuff
  -- with actiohns/replace, actions/quickfix, actions/quit
  -- create a mappings.lua thing that does the mapping to actions based on opts
  -- the actions can call renderResultsHeader or some sort of updateStatus to update stuff
  -- local replace = require('grug-far/rg/replace')

  return buf
end

return M
