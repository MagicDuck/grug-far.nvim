local renderHelp = require('grug-far/render/help')
local renderInput = require('grug-far/render/input')
local renderResults = require('grug-far/render/results')
local utils = require('grug-far/utils')

local function render(params, context)
  local buf = params.buf
  local inputs = context.state.inputs

  renderHelp({ buf = buf }, context)

  inputs.search = renderInput({
    buf = buf,
    lineNr = 1,
    extmarkName = "search",
    icon = 'searchInput',
    label = "Search:",
    placeholder = "ex: foo    foo([a-z0-9]*)    fun\\(",
  }, context)

  vim.api.nvim_buf_set_name(buf,
    'Grug FAR' .. utils.strEllideAfter(inputs.search, context.options.maxSearchCharsInTitles, ': '))

  inputs.replacement = renderInput({
    buf = buf,
    lineNr = 2,
    extmarkName = "replace",
    icon = 'replaceInput',
    label = "Replace:",
    placeholder = "ex: bar    ${1}_foo    $$MY_ENV_VAR ",
  }, context)

  inputs.filesGlob = vim.trim(renderInput({
    buf = buf,
    lineNr = 3,
    extmarkName = "files_glob",
    icon = 'filesFilterInput',
    label = "Files Filter:",
    placeholder = "ex: *.lua     *.{css,js}    **/docs/*.md",
  }, context))

  inputs.flags = vim.trim(renderInput({
    buf = buf,
    lineNr = 4,
    extmarkName = "flags",
    icon = 'flagsInput',
    label = "Flags:",
    placeholder = "ex: --hidden (-.) --ignore-case (-i) --multiline (-U)",
  }, context))

  renderResults({
    buf = buf,
    minLineNr = 6,
    inputs = inputs
  }, context)
end

return render
