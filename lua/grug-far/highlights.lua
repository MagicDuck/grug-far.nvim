local M = {}

-- local prefixhl = vim.api.nvim_get_hl(0, { name = 'NormalFloat' })
-- local numhl = vim.api.nvim_get_hl(0, { name = 'Number' })
-- prefixhl.fg = numhl.fg
-- prefixhl.bold = true
-- local edgehl = vim.api.nvim_get_hl(0, { name = 'FloatBorder' })

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
  -- TODO (sbadragan): should be nicer??
  GrugFarResultsPath = { default = true, link = '@string.special.path' },

  -- TODO (sbadragan): use vim.g.background? But does it adjust to colorscheme change?
  -- GrugFarResultsLineNo = { link = 'Number', default = true },
  -- GrugFarResultsLineColumn = { link = 'Number', default = true },
  -- GrugFarResultsNumbersSeparator = { link = 'Normal', default = true },
  -- GrugFarResultsLinePrefixEdge = { default = true, link = 'Normal' },
  --
  -- GrugFarResultsLineNo = prefixhl,
  -- GrugFarResultsLineColumn = prefixhl,
  -- GrugFarResultsNumbersSeparator = { link = 'NormalFloat', default = true },
  -- GrugFarResultsLinePrefixEdge = edgehl,

  -- TODO (sbadragan): we'll have to change the names for the first two, since themes already have
  -- them overriden, and they will look weird
  GrugFarResultsLineNo = { default = true, link = 'NormalFloat' },
  GrugFarResultsLineColumn = { default = true, link = 'NormalFloat' },
  GrugFarResultsNumbersSeparator = { default = true, link = 'NormalFloat' },
  -- GrugFarResultsLinePrefixEdge = { default = true, link = 'FloatBorder' },
  GrugFarResultsLinePrefixEdge = { default = true, link = 'Normal' },

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

-- vim.api.get_hl('NormalFloat')
-- local function mod_hl(hl_name, opts)
--   local is_ok, hl_def = pcall(vim.api.nvim_get_hl_by_name, hl_name, true)
--   if is_ok then
--     for k, v in pairs(opts) do
--       hl_def[k] = v
--     end
--     vim.api.nvim_set_hl(0, hl_name, hl_def)
--   end
-- end

return M
