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
      { { "  Search", 'DiagnosticInfo' } },
    },
  }, context)

  inputs.replacement = renderInput({
    buf = buf,
    lineNr = 2,
    extmarkName = "replace",
    label_virt_lines = {
      { { "  Replace", 'DiagnosticInfo' } },
    },
  }, context)

  inputs.filesGlob = vim.trim(renderInput({
    buf = buf,
    lineNr = 3,
    extmarkName = "files_glob",
    label_virt_lines = {
      { { " 󱪣 Files Glob", 'DiagnosticInfo' } },
    },
  }, context))

  inputs.flags = vim.trim(renderInput({
    buf = buf,
    lineNr = 4,
    extmarkName = "flags",
    label_virt_lines = {
      { { "  Flags", 'DiagnosticInfo' } },
    },
  }, context))

  renderResults({
    buf = buf,
    minLineNr = 6,
    inputs = inputs
  }, context)
end

return render
