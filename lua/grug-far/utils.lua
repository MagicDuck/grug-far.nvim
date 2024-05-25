local uv = vim.loop
local is_win = vim.api.nvim_call_function('has', { 'win32' }) == 1
local M = {}

--- setTimeout, like in js
---@param callback fun()
---@param timeout integer milliseconds
---@return uv_timer_t timer
function M.setTimeout(callback, timeout)
  local timer = uv.new_timer()
  timer:start(timeout, 0, function()
    timer:stop()
    timer:close()
    vim.schedule(callback)
  end)
  return timer
end

--- clear the timeout
---@param timer uv_timer_t
function M.clearTimeout(timer)
  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

--- debounce given function
---@param callback fun(parms: any)
---@param timeout integer milliseconds
---@return fun(params: any) deobuncedCallback
function M.debounce(callback, timeout)
  local timer
  return function(params)
    M.clearTimeout(timer)
    timer = M.setTimeout(function()
      callback(params)
    end, timeout)
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
  uv.fs_open(path, 'r', uv.constants.O_RDONLY, function(err1, fd)
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
  uv.fs_open(path, 'w+', uv.constants.O_RDWR + uv.constants.O_TRUNC, function(err1, fd)
    if err1 then
      return callback(err1)
    end
    if not fd then
      return callback('could not open file ' .. path)
    end
    uv.fs_write(fd, data, 0, function(err2)
      if err2 then
        return callback(err2)
      end
      uv.fs_close(fd, function(err3)
        if err3 then
          return callback(err3)
        end
        return callback(nil)
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

M.eol = is_win and '\r\n' or '\n'

return M
