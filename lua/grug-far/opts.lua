local M = {}

---@type GrugFarOptions
M.defaultOptions = {
  -- debounce milliseconds for issuing search while user is typing
  -- prevents excesive searching
  debounceMs = 500,

  -- minimum number of chars which will cause a search to happen
  -- prevents performance issues in larger dirs
  minSearchChars = 2,

  -- max number of parallel replacements tasks
  maxWorkers = 4,

  -- ripgrep executable to use, can be a different path if you need to configure
  rgPath = 'rg',

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
  -- set to '' or false to unset. Mappings with no normal mode value will be removed from the help header
  -- you can specify either a string which is then used as the mapping for both normmal and insert mode
  -- or you can specify a table of the form { [mode] = <lhs> } (ex: { i = '<C-enter>', n = '<localleader>gr'})
  -- it is recommended to use <localleader> though as that is more vim-ish
  -- see https://learnvimscriptthehardway.stevelosh.com/chapters/11.html#local-leader
  keymaps = {
    replace = { n = '<localleader>r' },
    qflist = { n = '<localleader>q' },
    syncLocations = { n = '<localleader>s' },
    syncLine = { n = '<localleader>l' },
    close = { n = '<localleader>c' },
    historyOpen = { n = '<localleader>t' },
    historyAdd = { n = '<localleader>a' },
    refresh = { n = '<localleader>f' },
    gotoLocation = { n = '<enter>' },
    pickHistoryEntry = { n = '<enter>' },
  },

  -- separator between inputs and results, default depends on nerdfont
  resultsSeparatorLineChar = '',

  -- spinner states, default depends on nerdfont, set to false to disable
  spinnerStates = {
    '󱑋 ',
    '󱑌 ',
    '󱑍 ',
    '󱑎 ',
    '󱑏 ',
    '󱑐 ',
    '󱑑 ',
    '󱑒 ',
    '󱑓 ',
    '󱑔 ',
    '󱑕 ',
    '󱑖 ',
  },

  -- whether to report duration of replace/sync operations
  reportDuration = true,

  -- maximum width of help header
  headerMaxWidth = 100,

  -- icons for UI, default ones depend on nerdfont
  -- set individul ones to '' to disable, or set enabled = false for complete disable
  icons = {
    -- whether to show icons
    enabled = true,

    actionEntryBullet = '󰐊 ',

    searchInput = ' ',
    replaceInput = ' ',
    filesFilterInput = ' ',
    flagsInput = '󰮚 ',

    resultsStatusReady = '󱩾 ',
    resultsStatusError = ' ',
    resultsStatusSuccess = '󰗡 ',
    resultsActionMessage = '  ',
    resultsEditedIndicator = ' ',

    historyTitle = '  ',
  },

  -- placeholders to show in input areas when they are empty
  -- set individul ones to '' to disable, or set enabled = false for complete disable
  placeholders = {
    -- whether to show placeholders
    enabled = true,

    search = 'ex: foo    foo([a-z0-9]*)    fun\\(',
    replacement = 'ex: bar    ${1}_foo    $$MY_ENV_VAR ',
    filesFilter = 'ex: *.lua     *.{css,js}    **/docs/*.md',
    flags = 'ex: --help --ignore-case (-i) <relative-file-path> --replace= (empty replace) --multiline (-U)',
  },

  -- strings to auto-fill in each input area at start
  -- those are not necessarily useful as global defaults but quite useful as overrides
  -- when lauching through the lua api. For example, this is how you would lauch grug-far.nvim
  -- with the current word under the cursor as the search string
  --
  -- require('grug-far').grug_far({ prefills = { search = vim.fn.expand("<cword>") } })
  --
  prefills = {
    search = '',
    replacement = '',
    filesFilter = '',
    flags = '',
  },

  -- search history settings
  history = {
    -- maximum number of lines in history file, end of file will be smartly truncated
    -- to remove oldest entries
    maxHistoryLines = 10000,

    -- directory where to store history file
    historyDir = vim.fn.stdpath('state') .. '/grug-far',

    -- configuration for when to auto-save history entries
    autoSave = {
      -- whether to auto-save at all, trumps all other settings below
      enabled = true,

      -- auto-save after a replace
      onReplace = true,

      -- auto-save after sync all
      onSyncAll = true,

      -- auto-save after buffer is deleted
      onBufDelete = true,
    },
  },
}

---@class KeymapTable
---@field n? string
---@field i? string

---@alias KeymapDef KeymapTable | string | boolean

---@class Keymaps
---@field replace KeymapDef
---@field qflist KeymapDef
---@field syncLocations KeymapDef
---@field historyAdd KeymapDef
---@field historyOpen KeymapDef
---@field refresh KeymapDef
---@field syncLine KeymapDef
---@field close KeymapDef
---@field gotoLocation KeymapDef
---@field pickHistoryEntry KeymapDef

---@class KeymapsOverride
---@field replace? KeymapDef
---@field qflist? KeymapDef
---@field syncLocations? KeymapDef
---@field historyAdd? KeymapDef
---@field historyOpen? KeymapDef
---@field refresh? KeymapDef
---@field syncLine? KeymapDef
---@field close? KeymapDef
---@field gotoLocation? KeymapDef
---@field pickHistoryEntry? KeymapDef

---@class AutoSaveTable
---@field enabled boolean
---@field onReplace boolean
---@field onSyncAll boolean
---@field onBufDelete boolean

---@class AutoSaveTableOverride
---@field enabled? boolean
---@field onReplace? boolean
---@field onSyncAll? boolean
---@field onBufDelete? boolean

---@class HistoryTable
---@field maxHistoryLines integer
---@field historyDir string
---@field autoSave AutoSaveTable

---@class HistoryTableOverride
---@field maxHistoryLines? integer
---@field historyDir? string
---@field autoSave? AutoSaveTable

---@class IconsTable
---@field enabled boolean
---@field searchInput string
---@field actionEntryBullet string
---@field replaceInput string
---@field filesFilterInput string
---@field flagsInput string
---@field resultsStatusReady string
---@field resultsStatusError string
---@field resultsStatusSuccess string
---@field resultsActionMessage string
---@field resultsEditedIndicator string

---@class IconsTableOverride
---@field enabled? boolean
---@field searchInput? string
---@field actionEntryBullet? string
---@field replaceInput? string
---@field filesFilterInput? string
---@field flagsInput? string
---@field resultsStatusReady? string
---@field resultsStatusError? string
---@field resultsStatusSuccess? string
---@field resultsActionMessage? string
---@field resultsEditedIndicator? string

---@class PlaceholdersTable
---@field enabled boolean
---@field search string
---@field replacement string
---@field filesFilter string
---@field filesGlob? string deprecated, use filesFilter
---@field flags string

---@class PlaceholdersTableOverride
---@field enabled? boolean
---@field search? string
---@field replacement? string
---@field filesFilter? string
---@field filesGlob? string deprecated, use filesFilter
---@field flags? string

---@class PrefillsTable
---@field search string
---@field replacement string
---@field filesFilter string
---@field flags string

---@class PrefillsTableOverride
---@field search? string
---@field replacement? string
---@field filesFilter? string
---@field flags? string

---@class GrugFarOptions
---@field debounceMs integer
---@field minSearchChars integer
---@field maxWorkers integer
---@field rgPath string
---@field extraRgArgs string
---@field disableBufferLineNumbers boolean
---@field maxSearchCharsInTitles integer
---@field startInInsertMode boolean
---@field startCursorRow integer
---@field keymaps Keymaps
---@field resultsSeparatorLineChar string
---@field spinnerStates string[] | false
---@field reportDuration boolean
---@field headerMaxWidth integer
---@field icons IconsTable
---@field placeholders PlaceholdersTable
---@field prefills PrefillsTable
---@field history HistoryTable

---@class GrugFarOptionsOverride
---@field debounceMs? integer
---@field minSearchChars? integer
---@field maxWorkers? integer
---@field rgPath? string
---@field extraRgArgs? string
---@field disableBufferLineNumbers? boolean
---@field maxSearchCharsInTitles? integer
---@field startInInsertMode? boolean
---@field startCursorRow? integer
---@field keymaps? KeymapsOverride
---@field resultsSeparatorLineChar? string
---@field spinnerStates? string[] | false
---@field reportDuration? boolean
---@field headerMaxWidth? integer
---@field icons? IconsTableOverride
---@field placeholders? PlaceholdersTableOverride
---@field prefills? PrefillsTableOverride
---@field history? HistoryTableOverride

--- generates merged options
---@param options GrugFarOptionsOverride | GrugFarOptions
---@param defaults GrugFarOptions
---@return GrugFarOptions
function M.with_defaults(options, defaults)
  local newOptions = vim.tbl_deep_extend('force', defaults, options)

  -- deprecated prop names
  newOptions.placeholders.filesFilter = (
    options.placeholders
    and (options.placeholders.filesFilter or options.placeholders.filesGlob)
  ) or defaults.placeholders.filesFilter

  if options.placeholders and options.placeholders.filesGlob then
    vim.notify(
      'grug-far: options.placeholders.filesGlob deprecated. Please use options.placeholders.filesFilter instead!',
      vim.log.levels.WARN
    )
  end

  -- normalize keymaps opts
  for key, value in pairs(newOptions.keymaps) do
    if not value or value == '' then
      newOptions.keymaps[key] = {}
    end

    if type(value) == 'string' then
      newOptions.keymaps[key] = { i = value, n = value }
    end
  end

  return newOptions
end

--- gets icon with given name if icons enabled
---@param iconName string
---@param context GrugFarContext
---@return string|nil
function M.getIcon(iconName, context)
  local icons = context.options.icons
  if not icons.enabled then
    return nil
  end

  return icons[iconName]
end

return M
