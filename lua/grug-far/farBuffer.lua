local render = require('grug-far.render')
local search = require('grug-far.actions.search')
local utils = require('grug-far.utils')
local resultsList = require('grug-far.render.resultsList')
local inputs = require('grug-far.inputs')

local M = {}

--- set up all key maps
---@param buf integer
---@param context grug.far.Context
local function getActions(buf, context)
  local get_inst = function()
    return require('grug-far').get_instance(buf)
  end

  local keymaps = context.options.keymaps
  return {
    {
      text = 'Help',
      keymap = keymaps.help,
      description = 'Open up help window.',
      action = function()
        get_inst():help()
      end,
    },
    {
      text = 'Replace',
      keymap = keymaps.replace,
      description = "Perform replace. Note that compared to 'Sync All', replace can also handle multiline replacements.",
      action = function()
        get_inst():replace()
      end,
    },
    {
      text = 'Sync All',
      keymap = keymaps.syncLocations,
      description = 'Sync all result lines text (potentially manually modified) back to their originating files. You can refine the effect by manually deleting lines to exclude them.',
      action = function()
        get_inst():sync_all()
      end,
    },
    {
      text = 'Sync Line',
      keymap = keymaps.syncLine,
      description = 'Sync current result line text (potentially manually modified) back to its originating file.',
      action = function()
        get_inst():sync_line()
      end,
    },
    {
      text = 'Sync Next',
      keymap = keymaps.syncNext,
      description = 'Sync change at current line and move cursor to next match',
      action = function()
        get_inst():apply_next_change({ open_location = false, remove_synced = false, notify = true })
      end,
    },
    {
      text = 'Sync Prev',
      keymap = keymaps.syncPrev,
      description = 'Sync change at current line and move cursor to prev match',
      action = function()
        get_inst():apply_prev_change({ open_location = false, remove_synced = false, notify = true })
      end,
    },
    {
      text = 'Sync File',
      keymap = keymaps.syncFile,
      description = 'Sync changes within current file',
      action = function()
        get_inst():sync_file()
      end,
    },
    {
      text = 'History Open',
      keymap = keymaps.historyOpen,
      description = 'Open history window. The history window allows you to select and edit historical searches/replacements.',
      action = function()
        get_inst():history_open()
      end,
    },
    {
      text = 'History Add',
      keymap = keymaps.historyAdd,
      description = 'Add current search/replace as a history entry.',
      action = function()
        get_inst():history_add()
      end,
    },
    {
      text = 'Refresh',
      keymap = keymaps.refresh,
      description = 'Re-trigger search. This can be useful in situations where files have been changed externally for example.',
      action = function()
        get_inst():search()
      end,
    },
    {
      text = 'Goto',
      keymap = keymaps.gotoLocation,
      description = "When cursor is placed on a result file path, go to that file. When it's placed over a result line, go to the file/line/column of the match. If a <count> is entered beforehand, go to the location corresponding to <count> result line.",
      action = function()
        if vim.v.count then
          get_inst():goto_match(vim.v.count)
        end
        get_inst():goto_location()
      end,
    },
    {
      text = 'Open',
      keymap = keymaps.openLocation,
      description = "Same as 'Goto', but cursor stays in grug-far buffer. This can allow a quicker thumb-through result locations. Alternatively, you can use the '--context <num>' flag to see match contexts. If a <count> is entered beforehand, open the location corresponding to <count> result line.",
      action = function()
        if vim.v.count then
          get_inst():goto_match(vim.v.count)
        end
        get_inst():open_location()
      end,
    },
    {
      text = 'Open Next',
      keymap = keymaps.openNextLocation,
      description = "Move cursor to next result line relative to current line and trigger 'Open' action",
      action = function()
        local location = get_inst():goto_next_match()
        if location then
          get_inst():open_location()
        else
          get_inst():goto_first_input()
        end
      end,
    },
    {
      text = 'Open Prev',
      keymap = keymaps.openPrevLocation,
      description = "Move cursor to previous result line relative to current line and trigger 'Open' action",
      action = function()
        local location = get_inst():goto_prev_match()
        if location then
          get_inst():open_location()
        else
          get_inst():goto_first_input()
        end
      end,
    },
    {
      text = 'Apply Next',
      keymap = keymaps.applyNext,
      description = 'Apply change at current line, remove it from buffer and move cursor to / open next change',
      action = function()
        get_inst():apply_next_change()
      end,
    },
    {
      text = 'Apply Prev',
      keymap = keymaps.applyPrev,
      description = 'Apply change at current line, remove it from buffer and move cursor to / open prev change',
      action = function()
        get_inst():apply_prev_change()
      end,
    },
    {
      text = 'Quickfix',
      keymap = keymaps.qflist,
      description = 'Send result lines to the quickfix list. Deleting result lines will cause them not to be included. ',
      action = function()
        get_inst():open_quickfix()
      end,
    },
    {
      text = 'Abort',
      keymap = keymaps.abort,
      description = "Abort current operation. Can be useful if you've ended up doing too large of a search or if you've changed your mind about a replacement midway.",
      action = function()
        get_inst():abort()
      end,
    },
    {
      text = 'Close',
      keymap = keymaps.close,
      description = 'Close grug-far buffer/window. This is the same as `:bd` except that it will also ask you to confirm if there is a replace/sync in progress, as those would be aborted.',
      action = function()
        get_inst():close()
      end,
    },
    {
      text = 'Swap Engine',
      keymap = keymaps.swapEngine,
      description = 'Swap search engine with the next one.',
      action = function()
        get_inst():swap_engine()
      end,
    },
    {
      text = 'Toggle Show Search Command',
      keymap = keymaps.toggleShowCommand,
      description = 'Toggle showing search command. Can be useful for debugging purposes.',
      action = function()
        get_inst():toggle_show_search_command()
      end,
    },
    {
      text = 'Preview',
      keymap = keymaps.previewLocation,
      description = 'Preview location in floating window.',
      action = function()
        get_inst():preview_location()
      end,
    },
    {
      text = 'Swap Replacement Interpreter',
      keymap = keymaps.swapReplacementInterpreter,
      description = 'Swap replacement interpreter with the next one. For example, with the "lua" interpreter, you can use lua to generate your replacement for each match.',
      action = function()
        get_inst():swap_replacement_interpreter()
      end,
    },
    {
      text = 'Next Input',
      keymap = keymaps.nextInput,
      description = 'Goto next input. Cycles back.',
      action = function()
        get_inst():goto_next_input()
      end,
    },
    {
      text = 'Prev Input',
      keymap = keymaps.prevInput,
      description = 'Goto prev input. Cycles back.',
      action = function()
        get_inst():goto_prev_input()
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
---@param context grug.far.Context
local function updateBufName(buf, context)
  local staticTitle = context.options.staticTitle
  local title

  if staticTitle and #staticTitle > 0 then
    title = getNextUniqueBufName(buf, staticTitle, false)
  else
    title = getNextUniqueBufName(buf, 'Grug FAR', true)
      .. utils.strEllideAfter(
        context.engine.getSearchDescription(inputs.getValues(context, buf)),
        context.options.maxSearchCharsInTitles,
        ': '
      )
  end

  utils.buf_set_name(buf, title)
end

---@param buf integer
---@param context grug.far.Context
local function setupGlobalBackspaceOptOverrides(buf, context)
  local originalBackspaceOpt
  local function apply_overrides()
    -- this prevents backspacing over eol when clearing an input line
    -- for a better user experience
    originalBackspaceOpt = vim.deepcopy(vim.opt.backspace:get())
    vim.opt.backspace:remove('eol')
  end
  local function undo_overrides()
    vim.opt.backspace = originalBackspaceOpt
  end

  apply_overrides()

  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    group = context.augroup,
    buffer = buf,
    callback = apply_overrides,
  })
  vim.api.nvim_create_autocmd({ 'BufLeave' }, {
    group = context.augroup,
    buffer = buf,
    callback = undo_overrides,
  })
end

---@param win integer
---@param buf integer
---@param context grug.far.Context
---@param on_ready fun()
---@return integer bufId
function M.setupBuffer(win, buf, context, on_ready)
  vim.api.nvim_set_option_value('filetype', 'grug-far', { buf = buf })
  vim.api.nvim_set_option_value('swapfile', false, { buf = buf })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  -- settings for transient buffers
  if context.options.transient then
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  end

  if not context.options.backspaceEol then
    setupGlobalBackspaceOptOverrides(buf, context)
  end
  context.actions = getActions(buf, context)
  for _, action in ipairs(context.actions) do
    utils.setBufKeymap(buf, action.text, action.keymap, action.action)
  end

  if context.options.smartInputHandling then
    inputs.bindInputSaavyKeys(context, buf)
  end

  local debouncedSearch = utils.debounce(vim.schedule_wrap(search), context.options.debounceMs)
  local function searchOnChange()
    local state = context.state

    if state.searchDisabled then
      return
    end

    local _inputs = inputs.getValues(context, buf)
    -- only re-issue search when inputs have changed
    if vim.deep_equal(_inputs, state.lastInputs) then
      return
    end

    state.lastInputs = vim.deepcopy(_inputs)

    -- do a search immediately if either:
    -- 1. manually searching
    -- 2. auto debounce searching and query is empty, to improve responsiveness
    if state.normalModeSearch or context.engine.isEmptySearch(_inputs, context.options) then
      search({ buf = buf, context = context })
    else
      debouncedSearch({ buf = buf, context = context })
    end
  end

  local function handleBufferChange()
    render(buf, context)
    updateBufName(buf, context)

    local isInsertMode = vim.fn.mode():lower():find('i') ~= nil
    if not (context.state.normalModeSearch and isInsertMode) then
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
  vim.api.nvim_create_autocmd({ 'InsertLeave' }, {
    group = context.augroup,
    buffer = buf,
    callback = function()
      if context.state.normalModeSearch then
        searchOnChange()
      end
    end,
  })
  vim.api.nvim_buf_attach(buf, false, {
    on_bytes = vim.schedule_wrap(function(_, _, _, start_row, _, _, _, _, _, new_end_row_offset)
      if context.state.bufClosed then
        return
      end
      resultsList.markUnsyncedLines(buf, context, start_row, start_row + new_end_row_offset)
    end),
  })

  -- do the initial render
  local is_ready = false
  vim.schedule(function()
    render(buf, context)

    vim.schedule(function()
      local values = {}
      local engineOpts = context.options.engines[context.engine.type]
      for _, input in ipairs(context.engine.inputs) do
        local value = context.options.prefills[input.name]
        if value == nil and engineOpts.defaults[input.name] then
          value = engineOpts.defaults[input.name]
        end
        if value == nil and input.getDefaultValue then
          value = input.getDefaultValue(context)
        end
        values[input.name] = value
      end
      inputs.fill(context, buf, values, true)
      updateBufName(buf, context)

      pcall(vim.api.nvim_win_set_cursor, win, { context.options.startCursorRow, 0 })
      if context.options.startInInsertMode then
        vim.cmd('startinsert!')
      end

      render(buf, context)
      is_ready = true
      on_ready()

      -- launch a search in case there are prefills
      searchOnChange()
    end)
  end)

  -- fix for this bug: https://github.com/neovim/neovim/issues/16166
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = context.augroup,
    buffer = buf,
    callback = function()
      if is_ready then
        utils.fixShowTopVirtLines(context, buf)
      end
    end,
  })

  -- set up re-render of line number on cursor moved
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = context.augroup,
    buffer = buf,
    callback = function()
      local cursor_row = unpack(vim.api.nvim_win_get_cursor(0))

      local lastCursorLocation = context.state.lastCursorLocation
      if lastCursorLocation then
        if cursor_row == lastCursorLocation.row then
          return -- nothing to do
        end

        local mark = vim.api.nvim_buf_get_extmark_by_id(
          buf,
          context.locationsNamespace,
          lastCursorLocation.markId,
          { details = true }
        )
        if mark then
          local start_row, start_col, details = unpack(mark)
          ---@cast start_row integer
          if details and not details.invalid then
            resultsList.rerenderLineNumber(
              context,
              buf,
              lastCursorLocation.loc,
              { lastCursorLocation.markId, start_row, start_col, details },
              false
            )
            context.state.lastCursorLocation = nil
          end
        end
      end

      local loc, mark = resultsList.getResultLocation(cursor_row - 1, buf, context)
      if loc and mark and loc.lnum then
        resultsList.rerenderLineNumber(context, buf, loc, mark, true)
        local markId = unpack(mark)
        ---@cast markId integer
        context.state.lastCursorLocation = { loc = loc, row = cursor_row, markId = markId }
      end
    end,
  })

  return buf
end

return M
