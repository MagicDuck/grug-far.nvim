local M = {}

local defaultOptions = {
  -- debounce milliseconds for issuing search while user is typing
  -- prevents excesive searching
  debounceMs = 700,

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

  keymaps = {
    replace = '<C-enter>',
    qflist = '<C-q>',
    gotoLocation = '<enter>',
    close = '<C-x>'
  },

  -- separator between inputs and results, default depends on nerdfont
  resultsSeparatorLineChar = '',

  -- spinner states, default depends on nerdfont, set to nil to disable
  spinnerStates = {
    '󱑋 ', '󱑌 ', '󱑍 ', '󱑎 ', '󱑏 ', '󱑐 ', '󱑑 ', '󱑒 ', '󱑓 ', '󱑔 ', '󱑕 ', '󱑖 '
  },

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

  -- placeholders to show in inpuut areas when they are empty, set
  placeholders = {
    -- whether to show placeholders
    enabled = true,

    search = "ex: foo    foo([a-z0-9]*)    fun\\(",
    replacement = "ex: bar    ${1}_foo    $$MY_ENV_VAR ",
    filesGlob = "ex: *.lua     *.{css,js}    **/docs/*.md",
    flags = "ex: --help --hidden (-.) --ignore-case (-i) --multiline (-U) --fixed-strings (-F)",
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
