vim.cmd('set rtp+=deps/mini.nvim')
local minidoc = require('mini.doc')
minidoc.setup({
  script_path = '',
})

local hooks = vim.deepcopy(minidoc.default_hooks)
hooks.write_pre = function(lines)
  -- Remove first two lines with `======` and `------` delimiters to comply
  -- with `:h local-additions` template
  table.remove(lines, 1)
  table.remove(lines, 1)
  return lines
end

minidoc.generate({ 'lua/grug-far.lua' }, 'doc/grug-far-api.txt', { hooks = hooks })
minidoc.generate({ 'lua/grug-far/opts.lua' }, 'doc/grug-far-opts.txt', { hooks = hooks })
minidoc.generate(
  { 'lua/grug-far/highlights.lua' },
  'doc/grug-far-highlights.txt',
  { hooks = hooks }
)
minidoc.generate(
  { 'lua/grug-far/instances.lua' },
  'doc/grug-far-instance-api.txt',
  { hooks = hooks }
)
