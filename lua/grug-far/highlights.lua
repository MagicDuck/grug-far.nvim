local M = {}

local highlights = {
  GrugFarHelpHeader = { default = true, link = 'ModeMsg' },
  GrugFarHelpHeaderKey = { default = true, link = 'String' },
  GrugFarHelpWinHeader = { default = true, link = 'Title' },
  GrugFarHelpWinActionPrefix = { default = true, link = 'Title' },
  GrugFarHelpWinActionText = { default = true, link = 'ModeMsg' },
  GrugFarHelpWinActionKey = { default = true, link = 'Conceal' },
  GrugFarHelpWinActionDescription = { default = true, link = 'NormalFloat' },

  GrugFarInputLabel = { default = true, link = 'Identifier' },
  GrugFarInputPlaceholder = { default = true, link = 'Comment' },

  GrugFarResultsHeader = { default = true, link = 'Comment' },
  GrugFarResultsStats = { default = true, link = 'Comment' },
  GrugFarResultsActionMessage = { default = true, link = 'ModeMsg' },

  GrugFarResultsMatch = { default = true, link = '@diff.delta' },
  GrugFarResultsMatchAdded = { default = true, link = '@diff.plus' },
  GrugFarResultsMatchRemoved = { default = true, link = '@diff.minus' },
  GrugFarResultsPath = { default = true, link = '@string.special.path' },
  GrugFarResultsLineNo = { default = true, link = 'Number' },
  GrugFarResultsLineColumn = { default = true, link = 'Number' },
  GrugFarResultsChangeIndicator = { default = true, link = 'Changed' },
  GrugFarResultsRemoveIndicator = { default = true, link = 'Removed' },
  GrugFarResultsAddIndicator = { default = true, link = 'Added' },
  GrugFarResultsDiffSeparatorIndicator = { default = true, link = 'Normal' },
  GrugFarResultsCmdHeader = { default = true, link = '@text.uri' },
  GrugFarResultsNumberLabel = { default = true, link = 'Identifier' },
}

function M.setup()
  for k, v in pairs(highlights) do
    vim.api.nvim_set_hl(0, k, v)
  end
end

return M
