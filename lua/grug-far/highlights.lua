local M = {}

local highlights = {
  GrugFarHelpHeader = { default = true, link = 'ModeMsg' },
  GrugFarHelpHeaderKey = { default = true, link = 'Identifier' },
  GrugFarHelpWinHeader = { default = true, link = 'Title' },
  GrugFarHelpWinActionPrefix = { default = true, link = 'Title' },
  GrugFarHelpWinActionText = { default = true, link = 'ModeMsg' },
  GrugFarHelpWinActionKey = { default = true, link = 'Identifier' },
  GrugFarHelpWinActionDescription = { default = true, link = 'NormalFloat' },

  GrugFarInputLabel = { default = true, link = 'Identifier' },
  GrugFarInputPlaceholder = { default = true, link = 'Comment' },

  GrugFarResultsHeader = { default = true, link = 'Comment' },
  GrugFarResultsStats = { default = true, link = 'Comment' },
  GrugFarResultsActionMessage = { default = true, link = 'ModeMsg' },

  GrugFarResultsMatch = { default = true, link = '@diff.delta' },
  GrugFarResultsMatchAdded = { default = true, link = '@diff.plus' },
  GrugFarResultsMatchRemoved = { default = true, link = '@diff.minus' },
  GrugFarResultsPath = { default = true, link = '@markup.link' },

  GrugFarResultsLineNr = { default = true, link = 'LineNr' },
  GrugFarResultsCursorLineNo = { default = true, link = 'CursorLineNr' },
  GrugFarResultsColumnNr = { default = true, link = 'GrugFarResultsLineNr' },
  GrugFarResultsNumbersSeparator = { default = true, link = 'GrugFarResultsLineNr' },
  GrugFarResultsLineNumberEdge = { default = true, link = 'LineNr' },
  GrugFarResultsLineNumberBoundary = { default = true, link = 'Normal' },

  GrugFarResultsChangeIndicator = { default = true, bg = 'NONE', fg = '#d1242f' },
  GrugFarResultsRemoveIndicator = { default = true, bg = 'NONE', fg = '#d1242f' },
  GrugFarResultsAddIndicator = { default = true, bg = 'NONE', fg = '#055d20' },
  GrugFarResultsDiffSeparatorIndicator = { default = true, link = 'Normal' },
  GrugFarResultsCmdHeader = { default = true, link = '@text.uri' },
  GrugFarResultsNumberLabel = { default = true, link = 'Identifier' },
  GrugFarResultsLongLineStr = { default = true, link = 'Comment' },
}

function M.setup()
  for k, v in pairs(highlights) do
    vim.api.nvim_set_hl(0, k, v)
  end
end

return M
