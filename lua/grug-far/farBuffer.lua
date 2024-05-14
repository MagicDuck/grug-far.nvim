local render = require("grug-far/render")
local search = require('grug-far/actions/search')
local replace = require("grug-far/actions/replace")
local qflist = require("grug-far/actions/qflist")
local gotoLocation = require("grug-far/actions/gotoLocation")
local syncLocations = require("grug-far/actions/syncLocations")
local close = require("grug-far/actions/close")
local utils = require('grug-far/utils')

local M = {}

local function setBufKeymap(buf, modes, desc, lhs, callback)
  for i = 1, #modes do
    local mode = modes:sub(i, i)
    vim.api.nvim_buf_set_keymap(buf, mode, lhs, '',
      { noremap = true, desc = desc, callback = callback, nowait = true })
  end
end

local function setupKeymap(buf, context)
  local keymaps = context.options.keymaps
  if #keymaps.replace > 0 then
    setBufKeymap(buf, 'ni', 'Grug Far: apply replacements', keymaps.replace, function()
      replace({ buf = buf, context = context })
    end)
  end
  if #keymaps.qflist > 0 then
    setBufKeymap(buf, 'ni', 'Grug Far: send results to quickfix list', keymaps.qflist, function()
      qflist({ context = context })
    end)
  end
  if #keymaps.gotoLocation > 0 then
    setBufKeymap(buf, 'n', 'Grug Far: go to location', keymaps.gotoLocation, function()
      gotoLocation({ buf = buf, context = context })
    end)
  end
  if #keymaps.syncLocations > 0 then
    setBufKeymap(buf, 'ni', 'Grug Far: sync edited results text to locations', keymaps.syncLocations, function()
      syncLocations({ buf = buf, context = context })
    end)
  end
  if #keymaps.close > 0 then
    setBufKeymap(buf, 'niv', 'Grug Far: close', keymaps.close, function()
      close()
    end)
  end
end

local function updateBufName(buf, context)
  vim.api.nvim_buf_set_name(buf,
    'Grug FAR - ' ..
    context.count .. utils.strEllideAfter(context.state.inputs.search, context.options.maxSearchCharsInTitles, ': '))
end

local function setupGlobalOptOverrides(buf, context)
  local originalBackspaceOpt = vim.opt.backspace:get()
  local function onBufEnter()
    -- this prevents backspacing over eol when clearing an input line
    -- for a better user experience
    originalBackspaceOpt = vim.opt.backspace:get()
    vim.opt.backspace:remove('eol')
  end
  local function onBufLeave()
    vim.opt.backspace = originalBackspaceOpt
  end

  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    group = context.augroup,
    buffer = buf,
    callback = onBufEnter
  })
  vim.api.nvim_create_autocmd({ 'BufLeave' }, {
    group = context.augroup,
    buffer = buf,
    callback = onBufLeave
  })

  onBufEnter()
end

function M.createBuffer(win, context)
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'grug-far')
  vim.api.nvim_win_set_buf(win, buf)

  setupGlobalOptOverrides(buf, context)
  setupKeymap(buf, context)

  local debouncedSearch = utils.debounce(search, context.options.debounceMs)
  local function debouncedSearchOnChange()
    -- only re-issue search when inputs have changed
    local state = context.state
    if vim.deep_equal(state.inputs, state.lastInputs) then
      return
    end

    state.lastInputs = vim.deepcopy(state.inputs)
    debouncedSearch({ buf = buf, context = context })
  end

  local function handleBufferChange()
    render(buf, context)
    updateBufName(buf, context)
    debouncedSearchOnChange()
  end

  -- set up re-render on change
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = context.augroup,
    buffer = buf,
    callback = handleBufferChange
  })

  -- do the initial render
  vim.schedule(function()
    render(buf, context)

    local prefills = context.options.prefills
    vim.api.nvim_buf_set_lines(buf, 2, 6, true, {
      prefills.search,
      prefills.replacement,
      prefills.filesFilter,
      prefills.flags,
    })

    updateBufName(buf, context)

    vim.api.nvim_win_set_cursor(win, { context.options.startCursorRow, 0 })
    if context.options.startInInsertMode then
      vim.cmd('startinsert!')
    end

    -- launch a search in case there are prefills
    debouncedSearchOnChange()
  end)

  return buf
end

return M
