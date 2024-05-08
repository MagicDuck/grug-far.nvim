local M = {}

local defaultOptions = {
  -- debounce milliseconds for issuing search while user is typing
  -- prevents excesive searching
  debounceMs = 500,

  -- minimum number of chars which will cause a search to happen
  -- prevents performance issues in larger dirs
  minSearchChars = 2,

  -- max number of parallel replacements tasks
  maxWorkers = 4,

  -- extra args that you always want to pass to rg
  -- like for example if you always want context lines around matches
  extraRgArgs = '',

  -- buffer line numbers + match line numbers can get a bit visually overwhelming
  -- turn this off if you still like to see the line numbers
  disableBufferLineNumbers = true,

  -- maximum number of search chars to show in buffer and quickfix list titles
  -- zero disables showing it
  maxSearchCharsInTitles = 30,

  -- icons for UI, default ones depend on nerdfont
  icons = {
    -- whether to show icons
    enabled = true,

    searchInput = ' ',
    replaceInput = ' ',
    filesFilterInput = ' ',
    flagsInput = '󰮚 ',

    resultsStatusReady = '󱩾 ',
    resultsStatusError = ' ',
    resultsStatusSuccess = '󰗡 ',
    resultsActionMessage = '  '
  },

  -- separator between inputs and results, default depends on nerdfont
  resultsSeparatorLine = '',

  -- spinner states, default depends on nerdfont, set to nil to disable
  spinnerStates = {
    '󱑋 ', '󱑌 ', '󱑍 ', '󱑎 ', '󱑏 ', '󱑐 ', '󱑑 ', '󱑒 ', '󱑓 ', '󱑔 ', '󱑕 ', '󱑖 '
  },

  keymaps = {
    replace = '<C-enter>',
    qflist = '<C-q>',
    close = '<C-x>'
  }
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
