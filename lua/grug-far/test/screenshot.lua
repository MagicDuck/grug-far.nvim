local M = {}
local MiniTest = require('mini.test')

---------------------------------------------------------------------------------------------
--- copied over from mini.test, to remove the stuff we don't care about
---------------------------------------------------------------------------------------------

---@class grug.far.MiniTestScreenshot

---@param t { text: string[], attr: string[] }
---@return grug.far.MiniTestScreenshot
local function screenshot_new(t)
  local process_screen = function(arr_2d)
    local n_lines, n_cols = #arr_2d, #arr_2d[1]

    -- Prepend lines with line number of the form `01|`
    local n_digits = math.floor(math.log10(n_lines)) + 1
    local format = string.format('%%0%dd|%%s', n_digits)
    local lines = {}
    for i = 1, n_lines do
      table.insert(lines, string.format(format, i, table.concat(arr_2d[i])))
    end

    -- Make ruler
    local prefix = string.rep('-', n_digits) .. '|'
    local ruler = prefix .. ('---------|'):rep(math.ceil(0.1 * n_cols)):sub(1, n_cols)

    return string.format('%s\n%s', ruler, table.concat(lines, '\n'))
  end

  return setmetatable(t, {
    __tostring = function(x)
      return string.format('%s', process_screen(x.text))
    end,
  })
end

---@param s string
---@return string[]
local function string_to_chars(s)
  -- Can't use `vim.split(s, '')` because of multibyte characters
  local res = {}
  for i = 1, vim.fn.strchars(s) do
    table.insert(res, vim.fn.strcharpart(s, i - 1, 1))
  end
  return res
end

--- gets a screenshot from given text lines and attrs
---@param text_lines string[]
---@return grug.far.MiniTestScreenshot
function M.from_lines(text_lines)
  local f = function(x)
    return string_to_chars(x)
  end
  return screenshot_new({ text = vim.tbl_map(f, text_lines), attr = {} })
end

function M.fromChildBufLines(child)
  local lines = child.api.nvim_buf_get_lines(0, 0, -1, true)
  -- Note: we use this if we run into random extra lines
  -- local end_line = #lines
  -- for i = #lines, 2, -1 do
  --   if #lines[i] > 0 then
  --     end_line = i
  --     break
  --   end
  -- end
  --
  -- local trimmed = {}
  -- for i = 1, end_line, 1 do
  --   table.insert(trimmed, lines[i])
  -- end

  return M.from_lines(lines)
end

local function case_to_stringid(case)
  local desc = table.concat(case.desc, ' | ')
  if #case.args == 0 then
    return desc
  end
  local args = vim.inspect(case.args, { newline = '', indent = '' })
  return ('%s + args %s'):format(desc, args)
end

local function screenshot_write(screenshot, path)
  vim.fn.writefile(vim.split(tostring(screenshot), '\n'), path)
end

local function screenshot_read(path)
  -- General structure of screenshot with `n` lines:
  -- 1: ruler-separator
  -- 2, n+1: `prefix`|`text`
  -- n+2: empty line
  -- n+3: ruler-separator
  -- n+4, 2n+3: `prefix`|`attr`
  local lines = vim.fn.readfile(path)
  local text_lines = vim.list_slice(lines, 2, #lines)

  local f = function(x)
    return string_to_chars(x:gsub('^%d+|', ''))
  end
  return screenshot_new({ text = vim.tbl_map(f, text_lines), attr = {} })
end

local function screenshot_compare(screen_ref, screen_obs, opts)
  local compare = function(x, y, desc)
    if x ~= y then
      return false,
        ('Different %s. Reference: %s. Observed: %s.'):format(desc, vim.inspect(x), vim.inspect(y))
    end
    return true, ''
  end

  --stylua: ignore start
  local ok, cause
  ok, cause = compare(#screen_ref.text, #screen_obs.text, 'number of `text` lines')
  if not ok then return ok, cause end

  local lines_to_check, ignore_lines = {}, opts.ignore_lines or {}
  for i = 1, #screen_ref.text do
    if not vim.tbl_contains(ignore_lines, i) then
      table.insert(lines_to_check, i)
    end
  end

  for _, i in ipairs(lines_to_check) do
    ok, cause = compare(#screen_ref.text[i], #screen_obs.text[i], 'number of columns in `text` line ' .. i)
    if not ok then return ok, cause end

    for j = 1, #screen_ref.text[i] do
      ok, cause = compare(screen_ref.text[i][j], screen_obs.text[i][j], string.format('`text` cell at line %s column %s', i, j))
      if not ok then return ok, cause end
    end
  end
  --stylua: ignore end

  return true, ''
end

local ansi_codes = {
  fail = '\27[1;31m', -- Bold red
  pass = '\27[1;32m', -- Bold green
  emphasis = '\27[1m', -- Bold
  reset = '\27[0m',
}

local function add_style(x, ansi_code)
  return string.format('%s%s%s', ansi_codes[ansi_code], x, ansi_codes.reset)
end

local function error_with_emphasis(msg, ...)
  local lines = { '', add_style(msg, 'emphasis'), ... }
  error(table.concat(lines, '\n'), 0)
end

local function error_expect(subject, ...)
  local msg = string.format('Failed expectation for %s.', subject)
  error_with_emphasis(msg, ...)
end

function M.reference_screenshot(screenshot, path, opts)
  if screenshot == nil then
    return true
  end

  screenshot = screenshot_new(screenshot)

  opts = vim.tbl_deep_extend('force', { force = false }, opts or {})

  if path == nil then
    -- Sanitize path. Replace any control characters, whitespace, OS specific
    -- forbidden characters with '-' (with some useful exception)
    local linux_forbidden = [[/]]
    local windows_forbidden = [[<>:"/\|?*]]
    local pattern =
      string.format('[%%c%%s%s%s]', vim.pesc(linux_forbidden), vim.pesc(windows_forbidden))
    local replacements = setmetatable({ ['"'] = "'" }, {
      __index = function()
        return '-'
      end,
    })
    local name = case_to_stringid(MiniTest.current.case):gsub(pattern, replacements)

    -- Don't end with whitespace or dot (forbidden on Windows)
    name = name:gsub('[%s%.]$', '-')

    local basepath = 'tests/screenshots/' .. name
    path = basepath

    -- Deal with multiple screenshots
    if opts.count > 0 then
      path = basepath .. string.format('-%03d', opts.count)
    end
  end

  -- If there is no readable screenshot file, create it. Pass with note.
  if opts.force or vim.fn.filereadable(path) == 0 then
    local dir_path = vim.fn.fnamemodify(path, ':p:h')
    vim.fn.mkdir(dir_path, 'p')
    screenshot_write(screenshot, path)

    MiniTest.add_note('Created reference screenshot at path ' .. vim.inspect(path))
    return true
  end

  local reference = screenshot_read(path)

  -- Compare
  local are_same, cause = screenshot_compare(reference, screenshot, opts)

  if are_same then
    return true
  end

  local subject = 'screenshot equality to reference at ' .. vim.inspect(path)
  local context = string.format(
    '%s\nReference:\n%s\n\nObserved:\n%s',
    cause,
    tostring(reference),
    tostring(screenshot)
  )
  error_expect(subject, context)
end

return M
