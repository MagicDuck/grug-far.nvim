local M = {}

local highlights = {
  GrugFarHelpHeader = { default = true, link = 'ModeMsg' },
  GrugFarHelpHeaderKey = { default = true, link = 'Identifier' },
  GrugFarHelpWinHeader = { default = true, link = 'Title' },
  GrugFarHelpWinActionPrefix = { default = true, link = 'Title' },
  GrugFarHelpWinActionText = { default = true, link = 'ModeMsg' },
  GrugFarHelpWinActionKey = { default = true, link = 'Identifier' },
  GrugFarHelpWinActionDescription = { default = true, link = 'NormalFloat' },

  -- TODO (sbadragan): make this better?
  GrugFarInputLabel = { default = true, link = 'Identifier' },
  GrugFarInputPlaceholder = { default = true, link = 'Comment' },

  GrugFarResultsHeader = { default = true, link = 'Comment' },
  GrugFarResultsStats = { default = true, link = 'Comment' },
  GrugFarResultsActionMessage = { default = true, link = 'ModeMsg' },

  GrugFarResultsMatch = { default = true, link = 'DiffText' },
  GrugFarResultsMatchAdded = { default = true, link = 'DiffAdd' },
  GrugFarResultsMatchRemoved = { default = true, link = 'DiffDelete' },
  GrugFarResultsPath = { default = true, link = 'Underlined' },

  GrugFarResultsLineNr = { default = true, link = 'LineNr' },
  GrugFarResultsCursorLineNo = { default = true, link = 'CursorLineNr' },
  GrugFarResultsColumnNr = { default = true, link = 'GrugFarResultsLineNr' },
  GrugFarResultsNumbersSeparator = { default = true, link = 'GrugFarResultsLineNr' },

  GrugFarResultsChangeIndicator = { default = true, bg = 'NONE', fg = '#d1242f' },
  GrugFarResultsRemoveIndicator = { default = true, bg = 'NONE', fg = '#d1242f' },
  GrugFarResultsAddIndicator = { default = true, bg = 'NONE', fg = '#055d20' },
  GrugFarResultsDiffSeparatorIndicator = { default = true, link = 'Normal' },
  GrugFarResultsCmdHeader = { default = true, link = 'Underlined' },
  GrugFarResultsNumberLabel = { default = true, link = 'Identifier' },
  GrugFarResultsLongLineStr = { default = true, link = 'Comment' },
}

function M.setup()
  for k, v in pairs(highlights) do
    vim.api.nvim_set_hl(0, k, v)
  end
end

return M
