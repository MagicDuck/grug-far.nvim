local M = {}

function M.with_defaults(options)
  return vim.tbl_deep_extend('force', {
    -- debounce milliseconds for issuing search while user is typing
    -- prevents excesive searching
    debounceMs = 500,

    -- minimum number of chars which will cause a search to happen
    -- prevents performance issues in larger dirs
    minSearchChars = 2,

    -- extra args that you always want to pass to rg
    -- like for example if you always want context lines around matches
    extraRgArgs = '',

    -- highlight groups for various parts of the UI
    highlights = {
      helpHeader = 'WarningMsg',

      inputLabel = 'Identifier',
      inputPlaceholder = 'Comment',

      resultsHeader = 'Comment',
      resultsStats = 'Comment',
      resultsMatch = '@diff.delta',
      resultsPath = '@string.special.path',
      resultsLineNo = 'Number',
      resultsLineColumn = 'Number',
    }
  }, options)
end

return M
