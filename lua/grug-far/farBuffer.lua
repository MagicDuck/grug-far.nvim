local render = require('grug-far/render')
local search = require('grug-far/actions/search')
local replace = require('grug-far/actions/replace')
local qflist = require('grug-far/actions/qflist')
local gotoLocation = require('grug-far/actions/gotoLocation')
local openLocation = require('grug-far/actions/openLocation')
local syncLocations = require('grug-far/actions/syncLocations')
local syncLine = require('grug-far/actions/syncLine')
local close = require('grug-far/actions/close')
local help = require('grug-far/actions/help')
local abort = require('grug-far/actions/abort')
local historyOpen = require('grug-far/actions/historyOpen')
local historyAdd = require('grug-far/actions/historyAdd')
local toggleShowCommand = require('grug-far/actions/toggleShowCommand')
local swapEngine = require('grug-far/actions/swapEngine')
local utils = require('grug-far/utils')
local resultsList = require('grug-far/render/resultsList')
local inputs = require('grug-far/inputs')

local M = {}

--- set up all key maps
---@param buf integer
---@param context GrugFarContext
local function getActions(buf, context)
  local keymaps = context.options.keymaps
  return {
    {
      text = 'Actions / Help',
      keymap = keymaps.help,
      description = 'Open up help window.',
      action = function()
        help({ buf = buf, context = context })
      end,
    },
    {
      text = 'Replace',
      keymap = keymaps.replace,
      description = "Perform replace. Note that compared to 'Sync All', replace can also handle multiline replacements.",
      action = function()
        replace({ buf = buf, context = context })
      end,
    },
    {
      text = 'Sync All',
      keymap = keymaps.syncLocations,
      description = 'Sync all result lines text (potentially manually modified) back to their originating files. You can refine the effect by manually deleting lines to exclude them.',
      action = function()
        syncLocations({ buf = buf, context = context })
      end,
    },
    {
      text = 'Sync Line',
      keymap = keymaps.syncLine,
      description = 'Sync current result line text (potentially manually modified) back to its originating file.',
      action = function()
        syncLine({ buf = buf, context = context })
      end,
    },
    {
      text = 'History Open',
      keymap = keymaps.historyOpen,
      description = 'Open history window. The history window allows you to select and edit historical searches/replacements.',
      action = function()
        historyOpen({ buf = buf, context = context })
      end,
    },
    {
      text = 'History Add',
      keymap = keymaps.historyAdd,
      description = 'Add current search/replace as a history entry.',
      action = function()
        historyAdd({ context = context })
      end,
    },
    {
      text = 'Refresh',
      keymap = keymaps.refresh,
      description = 'Re-trigger search. This can be useful in situations where files have been changed externally for example.',
      action = function()
        search({ buf = buf, context = context })
      end,
    },
    {
      text = 'Goto',
      keymap = keymaps.gotoLocation,
      description = "When cursor is placed on a result file path, go to that file. When it's placed over a result line, go to the file/line/column of the match.",
      action = function()
        gotoLocation({ buf = buf, context = context })
      end,
    },
    {
      text = 'Open',
      keymap = keymaps.openLocation,
      description = "Same as 'Goto', but cursor stays in grug-far buffer. This can allow a quicker thumb-through result locations. Alternatively, you can use the '--context <num>' flag to see match contexts.",
      action = function()
        openLocation({ buf = buf, context = context })
      end,
    },
    {
      text = 'Quickfix',
      keymap = keymaps.qflist,
      description = 'Send result lines to the quickfix list. Deleting result lines will cause them not to be included. ',
      action = function()
        qflist({ buf = buf, context = context })
      end,
    },
    {
      text = 'Abort',
      keymap = keymaps.abort,
      description = "Abort current operation. Can be useful if you've ended up doing too large of a search or if you've changed your mind about a replacement midway.",
      action = function()
        abort({ buf = buf, context = context })
      end,
    },
    {
      text = 'Close',
      keymap = keymaps.close,
      description = 'Close grug-far buffer/window. This is the same as `:bd` except that it will also ask you to confirm if there is a replace/sync in progress, as those would be aborted.',
      action = function()
        close({ buf = buf, context = context })
      end,
    },
    {
      text = 'Swap Engine',
      keymap = keymaps.swapEngine,
      description = 'Swap search engine with the next one.',
      action = function()
        swapEngine({ buf = buf, context = context })
      end,
    },
    {
      text = 'Toggle Show Search Command',
      keymap = keymaps.toggleShowCommand,
      description = 'Toggle showing search command. Can be useful for debugging purposes.',
      action = function()
        toggleShowCommand({ buf = buf, context = context })
      end,
    },
  }
end

--- gets next unique buffer name prefix
---@param buf integer
---@param prefix string
---@param initialIncludesCount boolean
local function getNextUniqueBufName(buf, prefix, initialIncludesCount)
  local count = 1
  local title = prefix
  if initialIncludesCount then
    title = title .. ' - ' .. count
  end

  while true do
    local bufnr = vim.fn.bufnr(title)
    if bufnr == -1 or bufnr == buf then
      return title
    end
    count = count + 1
    title = prefix .. ' - ' .. count
  end
end

---@param buf integer
---@param context GrugFarContext
local function updateBufName(buf, context)
  local staticTitle = context.options.staticTitle
  local title

  if staticTitle and #staticTitle > 0 then
    title = getNextUniqueBufName(buf, staticTitle, false)
  else
    title = getNextUniqueBufName(buf, 'Grug FAR', true)
      .. utils.strEllideAfter(
        context.state.inputs.search,
        context.options.maxSearchCharsInTitles,
        ': '
      )
  end

  utils.buf_set_name(buf, title)
end

---@param buf integer
---@param context GrugFarContext
local function setupGlobalOptOverrides(buf, context)
  local originalBackspaceOpt = vim.deepcopy(vim.opt.backspace:get())
  local function onInsertEnter()
    -- this prevents backspacing over eol when clearing an input line
    -- for a better user experience
    vim.opt.backspace:remove('eol')
  end
  local function onInsertLeave()
    vim.opt.backspace = originalBackspaceOpt
  end

  vim.api.nvim_create_autocmd({ 'InsertEnter' }, {
    group = context.augroup,
    buffer = buf,
    callback = onInsertEnter,
  })
  vim.api.nvim_create_autocmd({ 'InsertLeave' }, {
    group = context.augroup,
    buffer = buf,
    callback = onInsertLeave,
  })

  onInsertEnter()
end

---@param win integer
---@param context GrugFarContext
---@return integer bufId
function M.createBuffer(win, context)
  local buf = vim.api.nvim_create_buf(not context.options.transient, true)
  vim.api.nvim_set_option_value('filetype', 'grug-far', { buf = buf })
  vim.api.nvim_set_option_value('swapfile', false, { buf = buf })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  -- settings for transient buffers
  if context.options.transient then
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  end
  vim.api.nvim_win_set_buf(win, buf)

  setupGlobalOptOverrides(buf, context)
  context.actions = getActions(buf, context)
  for _, action in ipairs(context.actions) do
    utils.setBufKeymap(buf, 'Grug Far: ' .. action.text, action.keymap, action.action)
  end

  local debouncedSearch = utils.debounce(vim.schedule_wrap(search), context.options.debounceMs)
  local function searchOnChange()
    -- only re-issue search when inputs have changed
    local state = context.state
    if vim.deep_equal(state.inputs, state.lastInputs) then
      return
    end

    state.lastInputs = vim.deepcopy(state.inputs)

    -- do a search immediately if either:
    -- 1. manually searching
    -- 2. auto debounce searching and query is empty string, to improve responsiveness
    if context.options.searchOnInsertLeave or state.inputs.search == '' then
      search({ buf = buf, context = context })
    else
      debouncedSearch({ buf = buf, context = context })
    end
  end

  local function handleBufferChange()
    render(buf, context)
    updateBufName(buf, context)

    local isInsertMode = vim.fn.mode():lower():find('i') ~= nil
    if not (context.options.searchOnInsertLeave and isInsertMode) then
      searchOnChange()
    end
  end

  -- set up re-render on change
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = context.augroup,
    buffer = buf,
    callback = handleBufferChange,
  })
  vim.api.nvim_create_autocmd({ 'WinResized' }, {
    group = context.augroup,
    callback = function()
      local isWindowAffected = vim.iter(vim.v.event.windows or {}):any(function(winId)
        return winId == win
      end)

      if isWindowAffected then
        handleBufferChange()
      end
    end,
  })
  if context.options.searchOnInsertLeave then
    vim.api.nvim_create_autocmd({ 'InsertLeave' }, {
      group = context.augroup,
      buffer = buf,
      callback = function()
        searchOnChange()
      end,
    })
  end
  vim.api.nvim_buf_attach(buf, false, {
    on_bytes = vim.schedule_wrap(function(_, _, _, start_row, _, _, _, _, _, new_end_row_offset)
      resultsList.markUnsyncedLines(buf, context, start_row, start_row + new_end_row_offset)
    end),
  })

  -- do the initial render
  vim.schedule(function()
    render(buf, context)

    inputs.fill(context, buf, context.options.prefills, true)
    updateBufName(buf, context)

    pcall(vim.api.nvim_win_set_cursor, win, { context.options.startCursorRow, 0 })
    if context.options.startInInsertMode then
      vim.cmd('startinsert!')
    end

    -- launch a search in case there are prefills
    searchOnChange()
  end)

  return buf
end

return M
