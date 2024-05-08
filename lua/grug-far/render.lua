local renderHelp = require('grug-far/render/help')
local renderInput = require('grug-far/render/input')
local renderResults = require('grug-far/render/results')
local utils = require('grug-far/utils')

local function ensureTopEmptyLines(buf, count)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, count, false)
  for _ = #lines + 1, count do
    table.insert(lines, nil)
  end

  local foundNonEmpty = false
  local emptyLines = {}
  for i = 1, #lines do
    local line = lines[i]
    foundNonEmpty = foundNonEmpty or not (line and #line == 0)
    if foundNonEmpty then table.insert(emptyLines, "") end
  end

  if #emptyLines > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, emptyLines)
  end
end

local TOP_EMPTY_LINES = 2

local function render(params, context)
  local buf = params.buf
  local inputs = context.state.inputs

  local lineNr = 0
  ensureTopEmptyLines(buf, TOP_EMPTY_LINES)
  renderHelp({ buf = buf }, context)

  lineNr = lineNr + TOP_EMPTY_LINES
  inputs.search = renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = "search",
    icon = 'searchInput',
    label = "Search:",
    placeholder = "ex: foo    foo([a-z0-9]*)    fun\\(",
  }, context)

  vim.api.nvim_buf_set_name(buf,
    'Grug FAR' .. utils.strEllideAfter(inputs.search, context.options.maxSearchCharsInTitles, ': '))

  lineNr = lineNr + 1
  inputs.replacement = renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = "replace",
    icon = 'replaceInput',
    label = "Replace:",
    placeholder = "ex: bar    ${1}_foo    $$MY_ENV_VAR ",
  }, context)

  lineNr = lineNr + 1
  inputs.filesGlob = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = "files_glob",
    icon = 'filesFilterInput',
    label = "Files Filter:",
    placeholder = "ex: *.lua     *.{css,js}    **/docs/*.md",
  }, context))

  lineNr = lineNr + 1
  inputs.flags = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = "flags",
    icon = 'flagsInput',
    label = "Flags:",
    placeholder = "ex: --hidden (-.) --ignore-case (-i) --multiline (-U)",
  }, context))

  lineNr = lineNr + 2
  renderResults({
    buf = buf,
    minLineNr = lineNr,
    inputs = inputs
  }, context)
end

return render
