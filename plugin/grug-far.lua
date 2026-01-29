if vim.fn.has('nvim-0.11.0') == 0 then
  vim.notify(
    'grug-far needs nvim >= 0.11.0, please use version 1.6.3 if you would like to continue with nvim 0.10',
    vim.log.levels.ERROR
  )
  return
end

---Create command complete fn.
---@param name string
---@return grug.far.CmdCompleteFn
local function cmd_complete(name)
  return require('grug-far.utils').create_cmd_complete(function(ctx)
    if ctx.prev == name then
      return vim.tbl_keys(require('grug-far.opts').defaultOptions.engines)
    end
  end)
end

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
  complete = cmd_complete('GrugFar'),
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
  complete = cmd_complete('GrugFarWithin'),
})
