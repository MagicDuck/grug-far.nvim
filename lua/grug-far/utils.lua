local uv = vim.loop
local is_win = vim.api.nvim_call_function('has', { 'win32' }) == 1
local M = {}

---@type number?
M.scratch_buf = nil

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

--- finds location of given substring in string
---@param str string
---@param substr string
---@return integer | nil, integer | nil
function M.strFindLast(str, substr)
  local i = 0
  local j = nil
  while true do
    local i2, j2 = string.find(str, substr, i + 1, true)
    if i2 == nil then
      break
    end
    i = i2
    j = j2
  end

  if j == nil then
    return nil, nil
  end

  return i, j
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
---@param callback fun(err: string , data: nil) | fun(err: nil, data: string)
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

---@param context GrugFarContext
function M.isMultilineSearchReplace(context)
  local inputs = context.state.inputs
  local multilineFlags = { '--multiline', '-U', '--multiline-dotall' }
  if #inputs.flags > 0 then
    for flag in string.gmatch(inputs.flags, '%S+') do
      if M.isBlacklistedFlag(flag, multilineFlags) then
        return true
      end
    end
  end
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

--- get text in visual selection
--- if multiline, lines are joined
---@return string
function M.getVisualSelectionText()
  local start_pos = vim.api.nvim_buf_get_mark(0, '<')
  local end_pos = vim.api.nvim_buf_get_mark(0, '>')
  local lines = vim.fn.getline(start_pos[1], end_pos[1])
  -- add when only select in 1 line
  local plusEnd = 0
  local plusStart = 1
  if #lines == 0 then
    return ''
  elseif #lines == 1 then
    plusEnd = 1
    plusStart = 1
  end
  lines[#lines] = string.sub(lines[#lines], 0, end_pos[2] + plusEnd)
  lines[1] = string.sub(lines[1], start_pos[2] + plusStart, string.len(lines[1]))
  local query = table.concat(lines, '')
  return query
end

--- aborts all tasks
---@param context GrugFarContext
---@return boolean if any aborted
function M.abortTasks(context)
  local abortedAny = false
  for _, abort_fn in pairs(context.state.abort) do
    if abort_fn then
      abort_fn()
      abort_fn = nil
      abortedAny = true
    end
  end
  return abortedAny
end

---@param keymap KeymapDef
---@return string | nil
function M.getActionMapping(keymap)
  local lhs = keymap.n
  if not lhs or #lhs == 0 then
    return nil
  end
  if vim.g.maplocalleader then
    lhs = lhs:gsub('<localleader>', vim.g.maplocalleader)
  end
  if vim.g.mapleader then
    lhs = lhs:gsub('<leader>', vim.g.mapleader == ' ' and '<SPC>' or vim.g.mapleader)
  end

  if not (lhs:sub(1, 1) == '<' and lhs:sub(#lhs, #lhs) == '>') then
    lhs = '<' .. lhs .. '>'
  end

  return lhs
end

M.eol = is_win and '\r\n' or '\n'

return M
