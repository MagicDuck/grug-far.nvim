local M = {}

local highlights = {
  helpHeader = 'WarningMsg',

  inputLabel = 'Identifier',
  inputPlaceholder = 'Comment',

  resultsHeader = 'Comment',
  resultsStats = 'Comment',
  resultsActionMessage = 'ModeMsg',

  resultsMatch = '@diff.delta',
  resultsPath = '@string.special.path',
  resultsLineNo = 'Number',
  resultsLineColumn = 'Number',
}
local highlights = {
  GrugFarHelpHeader = 'WarningMsg',

  GrugFarInputLabel = 'Identifier',
  GrugFarInputPlaceholder = 'Comment',

  GrugFarResultsHeader = 'Comment',
  GrugFarResultsStats = 'Comment',
  GrugFarResultsActionMessage = 'ModeMsg',
  GrugFarResultsMatch = '@diff.delta',
  GrugFarResultsPath = '@string.special.path',
  GrugFarResultsLineNo = 'Number',
  GrugFarResultsLineColumn = 'Number',
}

function M.with_defaults(options)
  local newOptions = vim.tbl_deep_extend('force', defaultOptions, options)
  newOptions.icons.resultsStatusProgressSeq = options.icons and options.icons.resultsStatusProgressSeq or
    defaultOptions.icons.resultsStatusProgressSeq

  return newOptions
end

function M.getIcon(iconName, context)
  local icons = context.options.icons
  if not icons.enabled then
    return nil
  end

  return icons[iconName]
end

return M
