local M = {}

M.defaultOptions = {
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

  -- whether to start in insert mode,
  -- set to false for normal mode
  startInInsertMode = true,

  -- row in the window to position the cursor at at start
  startCursorRow = { 3, 0 },

  -- shortcuts for the actions you see at the top of the buffer
  -- set to '' to unset. Unset mappings will be removed from the help header
  keymaps = {
    replace = '<C-enter>',
    qflist = '<C-q>',
    gotoLocation = '<enter>',
    close = '<C-x>'
  },

  -- separator between inputs and results, default depends on nerdfont
  resultsSeparatorLineChar = '',

  -- spinner states, default depends on nerdfont, set to false to disable
  spinnerStates = {
    '󱑋 ', '󱑌 ', '󱑍 ', '󱑎 ', '󱑏 ', '󱑐 ', '󱑑 ', '󱑒 ', '󱑓 ', '󱑔 ', '󱑕 ', '󱑖 '
  },

  -- icons for UI, default ones depend on nerdfont
  -- set individul ones to '' to disable, or set enabled = false for complete disable
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

  -- placeholders to show in input areas when they are empty
  -- set individul ones to '' to disable, or set enabled = false for complete disable
  placeholders = {
    -- whether to show placeholders
    enabled = true,

    search = "ex: foo    foo([a-z0-9]*)    fun\\(",
    replacement = "ex: bar    ${1}_foo    $$MY_ENV_VAR ",
    filesGlob = "ex: *.lua     *.{css,js}    **/docs/*.md",
    flags = "ex: --help --hidden (-.) --ignore-case (-i) --multiline (-U) --fixed-strings (-F)",
  },

  -- strings to auto-fill in each input area at start
  -- those are not necessarily useful as global defaults but quite useful as overrides
  -- when lauching through the lua api. For example, this is how you would lauch grug-far.nvim
  -- with the currennt word under the curos as the search string
  --
  -- require('grug-far').grug_far({ prefills = { search = vim.fn.expand("<cword>") } })
  --
  prefills = {
    search = "",
    replacement = "",
    filesGlob = "",
    flags = ""
  }
}

function M.with_defaults(options, defaults)
  local newOptions = vim.tbl_deep_extend('force', defaults, options)
  -- special cases where option is a table that should be overriden as a whole
  newOptions.spinnerStates = options.spinnerStates or defaults.spinnerStates

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
