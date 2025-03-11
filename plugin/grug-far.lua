vim.api.nvim_create_user_command('GrugFar', function(params)
  local utils = require('grug-far.utils')
  local opts = require('grug-far.opts')

  local engineParam = params.fargs[1]
  local visual_selection_info
  if params.range > 0 then
    visual_selection_info = utils.get_current_visual_selection_info()
  end
  local resolvedOpts = opts.with_defaults({ engine = engineParam }, opts.getGlobalOptions())
  if params.mods and #params.mods > 0 then
    resolvedOpts.windowCreationCommand = params.mods .. ' split'
  end
  require('grug-far')._open_internal(
    resolvedOpts,
    { visual_selection_info = visual_selection_info }
  )
end, {
  nargs = '?',
  range = true,
  complete = 'custom,v:lua.GrugFarCompleteEngine',
})

vim.api.nvim_create_user_command('GrugFarWithin', function(params)
  local utils = require('grug-far.utils')
  local opts = require('grug-far.opts')

  local engineParam = params.fargs[1]
  local visual_selection_info
  if params.range > 0 then
    visual_selection_info = utils.get_current_visual_selection_info()
  end
  local resolvedOpts = opts.with_defaults({ engine = engineParam }, opts.getGlobalOptions())
  if params.mods and #params.mods > 0 then
    resolvedOpts.windowCreationCommand = params.mods .. ' split'
  end
  resolvedOpts.visualSelectionUsage = 'operate-within-range'
  require('grug-far')._open_internal(
    resolvedOpts,
    { visual_selection_info = visual_selection_info }
  )
end, {
  nargs = '?',
  range = true,
  complete = 'custom,v:lua.GrugFarCompleteEngine',
})
