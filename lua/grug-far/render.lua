local renderHelp = require('grug-far/render/help')
local renderInput = require('grug-far/render/input')
local renderResults = require('grug-far/render/results')

local function render(params, context)
  local buf = params.buf
  local inputs = {}

  renderHelp({ buf = buf }, context)

  inputs.search = renderInput({
    buf = buf,
    lineNr = 1,
    extmarkName = "search",
    label_virt_lines = {
      { { "  Search", 'Identifier' } },
    },
    placeholder_virt_text = {
      { "ex: foo    foo([a-z0-9]*)    fun\\(", 'Comment' }
    },
  }, context)

  inputs.replacement = renderInput({
    buf = buf,
    lineNr = 2,
    extmarkName = "replace",
    label_virt_lines = {
      { { "  Replace           ", 'Identifier' } },
    },
    placeholder_virt_text = {
      { "ex: bar    ${1}_foo    $$MY_ENV_VAR ", 'Comment' },
    },
  }, context)

  inputs.filesGlob = vim.trim(renderInput({
    buf = buf,
    lineNr = 3,
    extmarkName = "files_glob",
    label_virt_lines = {
      { { " 󱪣 Files Filter      ", 'Identifier' } },
    },
    placeholder_virt_text = {
      { "ex: *.lua     *.{css,js}    **/docs/*.md", 'Comment' }
    },
  }, context))

  inputs.flags = vim.trim(renderInput({
    buf = buf,
    lineNr = 4,
    extmarkName = "flags",
    label_virt_lines = {
      { { "  Flags             ", 'Identifier' } },
    },
    placeholder_virt_text = {
      { "ex: --hidden (-.) --ignore-case (-i) --multiline (-U)", 'Comment' }
    },
  }, context))

  renderResults({
    buf = buf,
    minLineNr = 6,
    inputs = inputs
  }, context)
end

return render
