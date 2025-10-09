local uv = vim.uv
local M = {}

M.is_win = vim.api.nvim_call_function('has', { 'win32' }) == 1

---@type number?
M.scratch_buf = nil

--- sets a given buffer's name without creating alternative buffers
---@param bufnr number the buffer to change the name of
---@param name string the new buffer name
function M.buf_set_name(bufnr, name)
  local old_name = vim.api.nvim_buf_get_name(bufnr)
  vim.api.nvim_buf_set_name(bufnr, name)
  if old_name ~= '' then
    local new_buf = vim.api.nvim_buf_call(bufnr, function()
      return vim.fn.bufnr('#')
    end)
    if new_buf ~= bufnr and new_buf ~= -1 and vim.api.nvim_buf_get_name(new_buf) == old_name then
      pcall(vim.api.nvim_buf_delete, new_buf, { force = true })
    end
  end
end

--- setTimeout, like in js
---@param callback fun()
---@param timeout integer milliseconds
---@return uv_timer_t timer
function M.setTimeout(callback, timeout)
  local timer = uv.new_timer()
  timer:start(timeout, 0, function()
    timer:stop()
    timer:close()
    callback()
  end)
  return timer
end

---@param filename string
function M.getFileType(filename)
  if not (M.scratch_buf and vim.api.nvim_buf_is_valid(M.scratch_buf)) then
    M.scratch_buf = vim.api.nvim_create_buf(false, true)
  end
  return vim.filetype.match({ filename = filename, buf = M.scratch_buf })
end

--- clear the timeout
---@param timer uv_timer_t
function M.clearTimeout(timer)
  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

--- debounce (trailing) given function
---@generic T: fun()
---@param callback T
---@param ms integer milliseconds
---@return T debouncedCallback
function M.debounce(callback, ms)
  local timer = uv.new_timer()
  return function(...)
    local params = vim.F.pack_len(...)
    timer:start(ms, 0, function()
      callback(vim.F.unpack_len(params))
    end)
  end
end

--- throttle (leading) given function
---@generic T: fun()
---@param callback T
---@param ms integer
---@return T throttledCallback
function M.throttle(callback, ms)
  local timer = uv.new_timer()
  return function(...)
    if not timer:is_active() then
      callback(...)
      timer:start(ms, 0, function() end)
    end
  end
end

--- finds last location of given substring in string (1-based index)
--- note: this does not handle utf-8, but neither does lua string.find, so
--- this is the best we can do atm
---@param str string
---@param substr string
---@return integer | nil
function M.strFindLast(str, substr)
  local pos = vim.fn.strridx(str, substr)
  if pos == -1 then
    return nil
  end

  return pos + 1
end

--- splits off last line in string
---@param str string
---@return string prefix, string lastLine
function M.splitLastLine(str)
  local i = M.strFindLast(str, '\n')
  if i then
    local pre = str:sub(1, i)
    local lastLine = str:sub(i + 1)
    return pre, lastLine
  end

  return '', str
end

--- truncate string and add ... after n chars, adding a prefix if non empty
---@param str string
---@param n integer
---@param prefix string | nil
---@return string
function M.strEllideAfter(str, n, prefix)
  if n == 0 or #str == 0 then
    return ''
  end
  return (prefix or '') .. (#str > n and string.sub(str, 1, n) .. '...' or str)
end

--- check if given flag is included in blacklist
---@param flag string
---@param blacklistedFlags? string[]
---@return boolean
function M.isBlacklistedFlag(flag, blacklistedFlags)
  if not blacklistedFlags then
    return false
  end

  for i = 1, #blacklistedFlags do
    local badFlag = blacklistedFlags[i]
    if
      flag == badFlag
      or vim.startswith(flag, badFlag .. ' ')
      or vim.startswith(flag, badFlag .. '=')
    then
      return true
    end
  end

  return false
end

--- async reads given file using libuv
---@param path string
---@param callback fun(err: string? , data: string?)
function M.readFileAsync(path, callback)
  uv.fs_open(path, 'r', 0, function(err1, fd)
    if err1 then
      return callback(err1)
    end
    if not fd then
      return callback('could not open file ' .. path)
    end
    uv.fs_fstat(fd, function(err2, stat)
      if err2 then
        return callback(err2)
      end
      if not stat then
        return callback('could not stat file ' .. path)
      end
      uv.fs_read(fd, stat.size, 0, function(err3, data)
        if err3 then
          return callback(err3)
        end
        uv.fs_close(fd, function(err4)
          if err4 then
            return callback(err4)
          end
          return callback(nil, data)
        end)
      end)
    end)
  end)
end

--- reads file lines synchronously
---@param path string file path
---@return string[] | nil
function M.readFileLinesSync(path)
  local fd = uv.fs_open(path, 'r', 0)
  if not fd then
    return
  end
  local stat = assert(uv.fs_fstat(fd))
  local data = assert(uv.fs_read(fd, stat.size, 0)) --[[@as string]]
  assert(uv.fs_close(fd))

  return vim.iter(vim.split(data, '\n')):map(M.getLineWithoutCarriageReturn):totable()
end

--- async overwrites file with given content
---@param path string
---@param data string
---@param callback fun(err: string | nil)
function M.overwriteFileAsync(path, data, callback)
  uv.fs_open(path, uv.constants.O_WRONLY, 0, function(err1, fd)
    if err1 then
      return callback(err1)
    end
    if not fd then
      return callback('could not open file ' .. path)
    end
    -- Note: we need to truncate manually instead of opening file in "w" mode
    -- since windows will create a new file instead of reusing existing file
    uv.fs_ftruncate(fd, 0, function(err2)
      if err2 then
        return callback(err2)
      end

      uv.fs_write(fd, data, 0, function(err3)
        if err3 then
          return callback(err3)
        end
        uv.fs_close(fd, function(err4)
          if err4 then
            return callback(err4)
          end
          return callback(nil)
        end)
      end)
    end)
  end)
end

--- add a keymapping
---@param buf integer
---@param desc string
---@param keymap KeymapDef
---@param callback fun()
function M.setBufKeymap(buf, desc, keymap, callback)
  local function setMapping(mode, lhs)
    vim.api.nvim_buf_set_keymap(
      buf,
      mode,
      lhs,
      '',
      { noremap = true, desc = desc, callback = callback, nowait = true }
    )
  end

  if keymap.i and keymap.i ~= '' then
    setMapping('i', keymap.i)
  end
  if keymap.n and keymap.n ~= '' then
    setMapping('n', keymap.n)
  end
end

---@param buf integer
---@param count integer
function M.ensureBufTopEmptyLines(buf, count)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, count, false)
  for _ = #lines + 1, count do
    table.insert(lines, nil)
  end

  local foundNonEmpty = false
  local emptyLines = {}
  for i = 1, #lines do
    local line = lines[i]
    foundNonEmpty = foundNonEmpty or not (line and #line == 0)
    if foundNonEmpty then
      table.insert(emptyLines, '')
    end
  end

  if #emptyLines > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, emptyLines)
  end
end

--- leave visual mode if in visual mode
---@return boolean if left visual mode
function M.leaveVisualMode()
  local isVisualMode = vim.fn.mode():lower():find('v') ~= nil
  if isVisualMode then
    -- needed to make visual selection work
    vim.fn.feedkeys(':', 'nx')
  end
  return isVisualMode
end

--- get text lines in visual selection
--- range row are 1-based, col are 0-based
---@return string[] lines, integer start_row, integer start_col, integer end_row, integer end_col
function M.getVisualSelectionLines()
  local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(0, '<'))
  if not start_col then
    start_col = 0
  end

  local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(0, '>'))
  if not end_col then
    end_col = -1
  end
  if end_col > 0 then
    end_col = end_col + 1 -- this is necessary due to end mark not being after the selection
  end

  local first_line = unpack(vim.api.nvim_buf_get_lines(0, start_row - 1, start_row, true))
  if first_line and start_col > #first_line then
    start_col = #first_line
  end
  local last_line = unpack(vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, true))
  if last_line and end_col > #last_line then
    end_col = -1
  end

  local lines = vim.api.nvim_buf_get_text(0, start_row - 1, start_col, end_row - 1, end_col, {})

  return lines, start_row, start_col, end_row, end_col
end

---@param keymap KeymapDef
---@return string | nil
function M.getActionMapping(keymap)
  local lhs = keymap.n
  if not lhs or #lhs == 0 then
    return nil
  end
  ---@diagnostic disable-next-line: undefined-field
  if vim.g.maplocalleader then
    ---@diagnostic disable-next-line: undefined-field
    lhs = lhs:gsub('<localleader>', vim.g.maplocalleader == ' ' and '<SPC>' or vim.g.maplocalleader)
  end
  ---@diagnostic disable-next-line: undefined-field
  if vim.g.mapleader then
    ---@diagnostic disable-next-line: undefined-field
    lhs = lhs:gsub('<leader>', vim.g.mapleader == ' ' and '<SPC>' or vim.g.mapleader)
  end

  return lhs
end

--- checks if string of flags contains given flag
---@param flagsStr string
---@param flagToCheck string
---@return boolean
function M.flagsStrContainsFlag(flagsStr, flagToCheck)
  if #flagsStr > 0 then
    for flag in string.gmatch(flagsStr, '%S+') do
      if flag == flagToCheck then
        return true
      end
    end
  end

  return false
end

--- splits string into parts separated by whitespace, ignoring spaces preceded by \
---@param pathsStr string
---@return string[]
function M.splitPaths(pathsStr)
  local _pathsStr = vim.trim(pathsStr:gsub('\n', ' '))
  local paths = {}
  local i = 1
  ---@type integer?
  local j = 1
  while true do
    j = string.find(_pathsStr, ' ', j, true)
    if j == nil then
      if i < #_pathsStr then
        local path = string.gsub(_pathsStr:sub(i), '\\ ', ' ')
        table.insert(paths, path)
      end
      break
    end

    local prevChar = _pathsStr:sub(j - 1, j - 1)
    if prevChar == ' ' then
      i = j + 1
    end
    if not (prevChar == '\\' or prevChar == ' ') then
      local path = string.gsub(_pathsStr:sub(i, j - 1), '\\ ', ' ')
      table.insert(paths, path)
      i = j + 1
    end
    j = j + 1
  end

  return paths
end

--- closes given uv handle if open
---@param handle uv_handle_t | nil
function M.closeHandle(handle)
  if handle and not handle:is_closing() then
    handle:close()
  end
end

--- Remove '\r' from the end of a line on Windows
---@param line string
---@return string
function M.getLineWithoutCarriageReturn(line)
  if not M.is_win then
    return line
  end

  local last_char = string.sub(line, -1)
  if last_char ~= '\r' then
    return line
  end

  return string.sub(line, 1, -2)
end

--- gets companion window in which open files
---@param context grug.far.Context
---@param buf integer
---@return integer window, boolean isNew
function M.getOpenTargetWin(context, buf)
  local preferredLocation = context.options.openTargetWindow.preferredLocation
  local grugfar_win = vim.fn.bufwinid(buf)
  -- get candidate windows in the current tab
  local tabpage = vim.api.nvim_win_get_tabpage(grugfar_win)
  local tabpage_windows = vim.api.nvim_tabpage_list_wins(tabpage)
  local target_windows = vim
    .iter(tabpage_windows)
    :filter(function(w)
      if w == grugfar_win then
        return false
      end

      local b = vim.api.nvim_win_get_buf(w)
      if not b then
        return false
      end

      local buftype = vim.api.nvim_get_option_value('buftype', { buf = b })
      if not vim.b[b].__grug_far_scratch_buf and (not buftype or buftype ~= '') then
        return false
      end

      local exclude = context.options.openTargetWindow.exclude
      if exclude then
        local filetype = vim.api.nvim_get_option_value('filetype', { buf = b })
        for _, filter in ipairs(exclude) do
          if type(filter) == 'string' then
            if filetype == filter then
              return false
            end
          elseif type(filter) == 'function' then
            if filter(w) then
              return false
            end
          end
        end
      end

      return true
    end)
    :totable()

  -- try to reuse a window that is already at preferredLocation
  if #target_windows > 0 then
    if preferredLocation == 'prev' then
      for _, win in ipairs(target_windows) do
        if win == context.prevWin then
          return context.prevWin, false
        end
      end
    else
      local ref_row, ref_col = unpack(vim.api.nvim_win_get_position(grugfar_win))
      local candidate_win
      local dist = 100000000000 -- some suitable large starting number
      for _, win in ipairs(target_windows) do
        local row, col = unpack(vim.api.nvim_win_get_position(win))
        if
          preferredLocation == 'left'
          and row == ref_row
          and col < ref_col
          and (ref_col - col) < dist
        then
          dist = ref_col - col
          candidate_win = win
        elseif
          preferredLocation == 'right'
          and row == ref_row
          and col > ref_col
          and (col - ref_col) < dist
        then
          dist = col - ref_col
          candidate_win = win
        elseif
          preferredLocation == 'above'
          and col == ref_col
          and row < ref_row
          and (ref_row - row) < dist
        then
          dist = ref_row - row
          candidate_win = win
        elseif
          preferredLocation == 'below'
          and col == ref_col
          and row > ref_row
          and (row - ref_row) < dist
        then
          dist = row - ref_row
          candidate_win = win
        end
      end

      if candidate_win then
        return candidate_win, false
      end
    end
  end

  -- create window at preferred location, keeping focus in grug-far win
  if
    not (
      preferredLocation == 'left'
      or preferredLocation == 'right'
      or preferredLocation == 'above'
      or preferredLocation == 'below'
    )
  then
    preferredLocation = 'left'
  end

  local new_win = vim.api.nvim_open_win(buf, false, {
    win = grugfar_win,
    ---@diagnostic disable-next-line: assign-type-mismatch
    split = preferredLocation,
  })

  return new_win, true
end

--- NOTE: this function lifted directly from neo-tree.nvim where it was produced
--- through a process of much sweat, blood and tears :)
--- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/a77af2e764c5ed4038d27d1c463fa49cd4794e07/lua/neo-tree/utils/init.lua#L1057
---
--- Escapes a path primarily relying on `vim.fn.fnameescape`. This function should
--- only be used when preparing a path to be used in a vim command, such as `:e`.
---
--- For Windows systems, this function handles punctuation characters that will
--- be escaped, but may appear at the beginning of a path segment. For example,
--- the path `C:\foo\(bar)\baz.txt` (where foo, (bar), and baz.txt are segments)
--- will remain unchanged when escaped by `fnaemescape` on a Windows system.
--- However, if that string is used to edit a file with `:e`, `:b`, etc., the open
--- parenthesis will be treated as an escaped character and the path separator will
--- be lost.
---
--- For more details, see issue #889 when this function was introduced, and further
--- discussions in #1264, #1352, and #1448.
--- @param path string
--- @return string
M.escape_path_for_cmd = function(path)
  local escaped_path = vim.fn.fnameescape(path)
  if M.is_win then
    -- there is too much history to this logic to capture in a reasonable comment.
    -- essentially, the following logic adds a number of `\` depending on the leading
    -- character in a path segment. see #1264, #1352, and #1448 in neo-tree.nvim repo for more info.
    local need_extra_esc = path:find('[%[%]`%$~]')
    local esc = need_extra_esc and '\\\\' or '\\'
    escaped_path = escaped_path:gsub('\\[%(%)%^&;]', esc .. '%1')
    if need_extra_esc then
      escaped_path = escaped_path:gsub("\\\\['` ]", '\\%1')
    end
  end
  return escaped_path
end

--- Normalizes paths. Expands a tilde at the beginning, environment variables.
--- Expands path providers into path lists.
---@param paths string[]
---@param context grug.far.Context
---@return string[]
M.normalizePaths = function(paths, context)
  local pathProviders = context.options.pathProviders
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  local normalizedPaths = {}
  for _, path in ipairs(paths) do
    local isProvider = false
    if pathProviders and vim.startswith(path, '<') and vim.endswith(path, '>') then
      local name = path:sub(2, -2)
      for providerName, providerFn in pairs(pathProviders) do
        if name == providerName then
          isProvider = true
          for _, p in ipairs(providerFn({ prevWin = context.prevWin })) do
            table.insert(normalizedPaths, M.normalizePath(p, cwd))
          end
        end
      end
    end
    if not isProvider then
      table.insert(normalizedPaths, M.normalizePath(path, cwd))
    end
  end

  return vim.fn.uniq(vim.fn.sort(normalizedPaths)) --[[@as [string] ]]
end

--- Normalizes a path. Expands a tilde at the beginning, environment variables.
--- Makes relative to cwd if under cwd
---@param path string
---@param cwd string
---@return string
M.normalizePath = function(path, cwd)
  if vim.startswith(path, '.') then
    return path
  end
  local normPath = vim.fs.normalize(path)
  local relPath = vim.fs.relpath(cwd, normPath)
  if relPath then
    return relPath
  end

  return normPath
end

--- parse a string containing json separated by newline into a list of tables
---@param str string
---@return table[]
M.str_to_json_list = function(str)
  local json_lines = vim.split(str, '\n')
  local json_data = {}
  local i = 1
  for j = 1, #json_lines, 1 do
    local json_str = json_lines[i]
    for k = i + 1, j, 1 do
      json_str = json_str .. '\n' .. json_lines[k]
    end

    local success, json_entry = pcall(vim.json.decode, json_str)
    if success then
      table.insert(json_data, json_entry)
      i = j + 1
    end
  end

  return json_data
end

---@param strict? boolean Whether to require visual mode to be active to return, defaults to False
---@return grug.far.VisualSelectionInfo?
function M.get_current_visual_selection_info(strict)
  local was_visual = M.leaveVisualMode()
  if strict and not was_visual then
    return
  end
  local lines, start_row, start_col, end_row, end_col = M.getVisualSelectionLines()

  return {
    file_name = vim.fn.expand('%:p:.'), -- relative path
    lines = lines,
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
  }
end

--- gets visual selection info as string
---@param visual_selection_info grug.far.VisualSelectionInfo
function M.get_visual_selection_info_as_str(visual_selection_info)
  return 'buffer-range='
    .. string.gsub(visual_selection_info.file_name, ' ', '\\ ')
    .. ':'
    .. visual_selection_info.start_row
    .. ':'
    .. visual_selection_info.start_col
    .. '-'
    .. visual_selection_info.end_row
    .. ':'
    .. visual_selection_info.end_col
end

--- gets buf range from string representation
---@param str string
---@return grug.far.VisualSelectionInfo?, string? err
function M.parse_buf_range_str(str)
  local prefix = 'buffer-range='
  if str:sub(1, #prefix) ~= prefix then
    return nil
  end

  local file_name, _start_row, _start_col, _end_row, _end_col =
    string.match(str, 'buffer%-range=(.+):(%d+):(%d+)-(%d+):(-?%d+)')

  local invalid_bufrange_message =
    'Invalid buffer range provided! Format is "buffer-range=<file_path>:<start_row>:<start_col>-<end_row>:<end_col>"'

  if not (file_name and _start_row and _start_col and _end_row and _end_col) then
    return nil, invalid_bufrange_message
  end
  ---@cast file_name string

  local buf = vim.fn.bufnr(file_name)
  if buf == -1 then
    return nil, 'Invalid buffer range provided! No buffer exists for the given file name.'
  end
  local num_lines = vim.api.nvim_buf_line_count(buf)

  local start_row = tonumber(_start_row) --[[@as integer?]]
  if not start_row then
    return nil, invalid_bufrange_message
  end
  if start_row < 1 then
    start_row = 1
  elseif start_row > num_lines then
    start_row = num_lines
  end

  local end_row = tonumber(_end_row) --[[@as integer?]]
  if not end_row then
    return nil, invalid_bufrange_message
  end
  if end_row < 1 then
    end_row = 1
  elseif end_row > num_lines then
    end_row = num_lines
  end
  if end_row < start_row then
    end_row = start_row
  end

  local start_col = tonumber(_start_col) --[[@as integer?]]
  if not start_col then
    return nil, invalid_bufrange_message
  end
  local first_line = unpack(vim.api.nvim_buf_get_lines(buf, start_row - 1, start_row, true))
  if first_line and start_col > #first_line then
    start_col = #first_line
  end

  local end_col = tonumber(_end_col) --[[@as integer?]]
  if not end_col then
    return nil, invalid_bufrange_message
  end
  local last_line = unpack(vim.api.nvim_buf_get_lines(buf, end_row - 1, end_row, true))
  if last_line and end_col > #last_line then
    end_col = -1
  end

  local bufrange = {
    file_name = file_name,
    lines = {},
    start_col = start_col,
    start_row = start_row,
    end_col = end_col,
    end_row = end_row,
  } --[[@as grug.far.VisualSelectionInfo]]
  bufrange.lines = M.readFromBufrange(bufrange)

  return bufrange
end

--- reads lines from given buffer bufrange
---@param bufrange grug.far.VisualSelectionInfo
---@return string[] lines
function M.readFromBufrange(bufrange)
  local buf = vim.fn.bufnr(bufrange.file_name)
  return vim.api.nvim_buf_get_text(
    buf,
    bufrange.start_row - 1,
    bufrange.start_col,
    bufrange.end_row - 1,
    bufrange.end_col,
    {}
  )
end

--- writes given lines into buffer bufrange
---@param bufrange grug.far.VisualSelectionInfo
---@param lines string[]
function M.writeInBufrange(bufrange, lines)
  local buf = vim.fn.bufnr(bufrange.file_name)
  vim.api.nvim_buf_set_text(
    buf,
    bufrange.start_row - 1,
    bufrange.start_col,
    bufrange.end_row - 1,
    bufrange.end_col,
    lines
  )
end

--- converts a scratch buffer to a real buffer
---@param buf integer
function M.convertScratchBufToRealBuf(buf)
  if vim.b[buf].__grug_far_scratch_buf then
    vim.b[buf].__grug_far_scratch_buf = nil
    vim.bo[buf].buftype = ''
    vim.api.nvim_buf_call(buf, function()
      vim.cmd('keepjumps silent! edit!')
    end)
  end
end

--- converts any existing scratch buffer to a real buffer
function M.convertAnyScratchBufToRealBuf()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.b[b].__grug_far_scratch_buf then
      M.convertScratchBufToRealBuf(b)
    end
  end
end

--- detects line ending
---@param contents string
function M.detect_eol(contents)
  local pos = contents:find('\n')
  if pos and pos > 1 and contents:sub(pos - 1, pos - 1) == '\r' then
    return '\r\n' -- dos
  else
    return '\n' -- unix and mac (post OSX)
  end
end

M.eol = M.is_win and '\r\n' or '\n'

--- strips trailing newline from str if it's there
---@param str string
---@return string
function M.strip_trailing_newline(str)
  if vim.endswith(str, '\n') then
    return str:sub(1, -2)
  end

  return str
end

--- replaces old with new in str once
---@param str string
---@param old string
---@param new string
function M.str_replace_once(str, old, new)
  local start, _end = str:find(old, 1, true)
  if start == nil then
    return str
  else
    return str:sub(1, start - 1) .. new .. str:sub(_end + 1)
  end
end

--- show row above the top line so that extmark virtual lines appear
--- fix for this bug: https://github.com/neovim/neovim/issues/16166
---@param context grug.far.Context
---@param buf integer
function M.fixShowTopVirtLines(context, buf)
  local top_screenpos = vim.fn.screenpos(0, 1, 0)
  local topVisible = top_screenpos.row ~= 0

  local topfill = 0

  if topVisible then
    if context.options.helpLine.enabled then
      topfill = topfill + 1
    end

    if context.options.showInputsTopPadding then
      topfill = topfill + 1
    end

    if not context.options.showCompactInputs then
      topfill = topfill + 1 -- first input label
    end
  end

  local grugfar_win = vim.fn.bufwinid(buf)
  vim.fn.win_execute(grugfar_win, 'lua vim.fn.winrestview({ topfill = ' .. topfill .. ' })')
end

--- gets bufrange if we have one specified in paths
---@param inputStr string
---@return grug.far.VisualSelectionInfo? bufrange, string? err
function M.getBufrange(inputStr)
  if #inputStr > 0 then
    local paths = M.splitPaths(inputStr)
    for _, path in ipairs(paths) do
      return M.parse_buf_range_str(path)
    end
  end

  return nil, nil
end

return M
