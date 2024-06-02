local M = {}

local nvim10 = vim.fn.has('nvim-0.10') > 0

local highlights = {
  GrugFarHelpHeader = { default = true, link = 'ModeMsg' },
  GrugFarHelpHeaderKey = { default = true, link = 'String' },

  GrugFarInputLabel = { default = true, link = 'Identifier' },
  GrugFarInputPlaceholder = { default = true, link = 'Comment' },

  GrugFarResultsHeader = { default = true, link = 'Comment' },
  GrugFarResultsStats = { default = true, link = 'Comment' },
  GrugFarResultsActionMessage = { default = true, link = 'ModeMsg' },

  GrugFarResultsMatch = { default = true, link = '@diff.delta' },
  GrugFarResultsPath = { default = true, link = '@string.special.path' },
  GrugFarResultsLineNo = { default = true, link = 'Number' },
  GrugFarResultsLineColumn = { default = true, link = 'Number' },
  GrugFarResultsChangeIndicator = { default = true, link = nvim10 and 'Changed' or 'diffLine' },
}

function M.setup()
  for k, v in pairs(highlights) do
    vim.api.nvim_set_hl(0, k, v)
  end
end

return M
