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
  startCursorRow = 3,

  -- shortcuts for the actions you see at the top of the buffer
  -- set to '' or false to unset. Unset mappings will be removed from the help header
  -- you can specify either a string which is then used as the mapping for both normmal and insert mode
  -- or you can specify a table of the form { [mode] = <lhs> } (ex: { i = '<C-enter>', n = '<leader>gr'})
  keymaps = {
    -- normal and insert mode
    replace = '<C-enter>',
    qflist = '<C-q>',
    syncLocations = '<C-s>',
    syncLine = '<C-a>',
    close = '<C-x>',

    -- normal mode only
    gotoLocation = { n = '<enter>' },
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
    filesFilter = "ex: *.lua     *.{css,js}    **/docs/*.md",
    flags =
    "ex: --help --ignore-case (-i) <relative-file-path> --replace= (empty replace) --multiline (-U)",
  },

  -- strings to auto-fill in each input area at start
  -- those are not necessarily useful as global defaults but quite useful as overrides
  -- when lauching through the lua api. For example, this is how you would lauch grug-far.nvim
  -- with the current word under the cursor as the search string
  --
  -- require('grug-far').grug_far({ prefills = { search = vim.fn.expand("<cword>") } })
  --
  prefills = {
    search = "",
    replacement = "",
    filesFilter = "",
    flags = ""
  }
}

function M.with_defaults(options, defaults)
  local newOptions = vim.tbl_deep_extend('force', defaults, options)

  -- deprecated prop names
  newOptions.placeholders.filesFilter = (options.placeholders and
      (options.placeholders.filesFilter or options.placeholders.filesGlob))
    or defaults.placeholders.filesFilter

  if options.placeholders and options.placeholders.filesGlob then
    vim.notify(
      'grug-far: options.placeholders.filesGlob deprecated. Please use options.placeholders.filesFilter instead!',
      vim.log.levels.WARN)
  end

  -- normalize keymaps opts
  for key, value in pairs(newOptions.keymaps) do
    if not value or value == '' then
      newOptions.keymaps[key] = nil
    end

    if type(value) == 'string' then
      newOptions.keymaps[key] = { i = value, n = value }
    end
  end

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
