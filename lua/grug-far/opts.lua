local M = {}

---@type GrugFarOptions
M.defaultOptions = {
  -- debounce milliseconds for issuing search while user is typing
  -- prevents excessive searching
  debounceMs = 500,

  -- minimum number of chars which will cause a search to happen
  -- prevents performance issues in larger dirs
  minSearchChars = 2,

  -- stops search after this number of matches as getting millions of matches is most likely pointless
  -- and can even freeze the search buffer sometimes
  -- can help prevent performance issues when searching for very common strings or when slowly starting
  -- to type your search string
  -- note that it can overshoot a little bit, but should not really matter in practice
  -- set to nil to disable
  maxSearchMatches = 2000,

  -- trim lines that are longer than this value in order to prevent neovim performance issues
  -- with long lines and annoying navigation
  -- set to -1 to disable
  maxLineLength = 1000,

  -- breakindentopt value to set on grug-far window. This controls the indentation of wrapped text.
  -- see :h breakindentopt for more details
  breakindentopt = 'shift:6',

  -- disable automatic debounced search and trigger search when leaving insert mode or making normal mode changes instead
  -- Note that normal mode changes such as `diw`, `rF`, etc will still trigger a search
  normalModeSearch = false,

  -- deprecated, was renamed to normalModeSearch
  searchOnInsertLeave = false,

  -- max number of parallel replacements tasks
  maxWorkers = 4,

  -- ripgrep executable to use, can be a different path if you need to configure
  -- deprecated, please use engines.ripgrep.path
  rgPath = 'rg',

  -- extra args that you always want to pass to rg
  -- like for example if you always want context lines around matches
  -- deprecated, please use engines.ripgrep.extraArgs
  extraRgArgs = '',

  -- engines that are enabled to use
  -- The order of the array dictates the order to rotate through when swappping
  -- engines
  enabledEngines = { 'ripgrep', 'astgrep', 'astgrep-rules' },

  -- search and replace engines configuration
  engines = {
    -- see https://github.com/BurntSushi/ripgrep
    ripgrep = {
      -- ripgrep executable to use, can be a different path if you need to configure
      path = 'rg',

      -- extra args that you always want to pass
      -- like for example if you always want context lines around matches
      extraArgs = '',

      -- whether to show diff of the match being replaced as opposed to just the
      -- replaced result. It usually makes it easier to understand the change being made
      showReplaceDiff = true,

      -- placeholders to show in input areas when they are empty
      -- set individual ones to '' to disable, or set enabled = false for complete disable
      placeholders = {
        -- whether to show placeholders
        enabled = true,

        search = 'e.g. foo   foo([a-z0-9]*)   fun\\(',
        replacement = 'e.g. bar   ${1}_foo   $$MY_ENV_VAR ',
        replacement_lua = 'e.g. if vim.startsWith(match, "use") \\n then return "employ" .. match \\n else return match end',
        replacement_vimscript = 'e.g. return "bob_" .. match',
        filesFilter = 'e.g. *.lua   *.{css,js}   **/docs/*.md   (specify one per line)',
        flags = 'e.g. --help --ignore-case (-i) --replace= (empty replace) --multiline (-U)',
        paths = 'e.g. /foo/bar   ../   ./hello\\ world/   ./src/foo.lua   ~/.config',
      },
    },
    -- see https://ast-grep.github.io
    astgrep = {
      -- ast-grep executable to use, can be a different path if you need to configure
      -- Note: as of this change in ast-grep: https://github.com/ast-grep/ast-grep/commit/15295de3f48aa39bee7c2af642fceb7742d9c156
      -- `sg` is compiled as an alias to `ast-grep` so cannot be used in here. Always use the path to `ast-grep`.
      path = 'ast-grep',

      -- extra args that you always want to pass
      -- like for example if you always want context lines around matches
      extraArgs = '',

      -- placeholders to show in input areas when they are empty
      -- set individual ones to '' to disable, or set enabled = false for complete disable
      placeholders = {
        -- whether to show placeholders
        enabled = true,

        search = 'e.g. $A && $A()   foo.bar($$$ARGS)   $_FUNC($_FUNC)',
        replacement = 'e.g. $A?.()   blah($$$ARGS)',
        replacement_lua = 'e.g. return vars.A == "blah" and "foo(" .. table.concat(vars.ARGS, ", ") .. ")" or match',
        filesFilter = 'e.g. *.lua   *.{css,js}   **/docs/*.md   (specify one per line, filters via ripgrep)',
        flags = 'e.g. --help (-h) --debug-query=ast --rewrite= (empty replace) --strictness=<STRICTNESS>',
        paths = 'e.g. /foo/bar   ../   ./hello\\ world/   ./src/foo.lua   ~/.config',
      },
    },

    ['astgrep-rules'] = {
      -- ast-grep executable to use, can be a different path if you need to configure
      path = 'ast-grep',

      -- extra args that you always want to pass
      -- like for example if you always want context lines around matches
      extraArgs = '',

      -- Globs to define non-standard mappings of file extension to language,
      -- as you might define in an ast-grep project config. Here they're used
      -- to fill a reasonable language (which is required) in the default-value
      -- for the the rules YAML input. Ideally these would be read directly
      -- from `sgconfig.yml`, but we're not going to implement that parsing.
      --
      -- Example:
      -- ```
      -- languageGlobs = { tsx = { "*.ts", ".js", "*.jsx", "*.tsx" } }
      -- ```
      --
      -- This will make then input pre-fill `language: tsx` if the
      -- current/previous file matches any of that list of globs. Setting these
      -- globs in`sgconfig.yml` is a way to make rules more-reusable - rather
      -- than write separate rules for each of the 4 languages, parse them all
      -- as the "superset" language (tsx), and write one rule based on that
      -- AST. This plugin will then infer (based on this option) that you
      -- probably want to target `language: tsx` when writing a rule for files
      -- that match any of these globs
      --
      -- ast-grep docs:
      -- https://ast-grep.github.io/reference/sgconfig.html#languageglobs
      languageGlobs = {},

      -- placeholders to show in input areas when they are empty
      -- set individual ones to '' to disable, or set enabled = false for complete disable
      placeholders = {
        -- whether to show placeholders
        enabled = true,

        --  rules would normally be multi-line, but we don't support multi-line
        --  placeholders. rules is filled with a default-value though, so it's
        --  rare to see it empty
        rules = 'e.g. id: my_rule_1 \\n language: lua\\nrule: \\n  pattern: await $A',
        filesFilter = 'e.g. *.lua   *.{css,js}   **/docs/*.md   (specify one per line, filters via ripgrep)',
        flags = 'e.g. --help (-h) --debug-query=ast --strictness=<STRICTNESS>',
        paths = 'e.g. /foo/bar   ../   ./hello\\ world/   ./src/foo.lua   ~/.config',
      },
    },
  },

  -- search and replace engine to use.
  -- Must be one of 'ripgrep' | 'astgrep' | 'astgrep-rules' | nil
  -- if nil, defaults to 'ripgrep'
  engine = 'ripgrep',

  -- replacement interpreters that are enabled for usage (in addition to the default).
  -- Those allow you to evaluate the replacement input as a an interpreted string for each search match.
  -- The result of that evaluation is used as the replacement in each case.
  -- Supported:
  -- * 'default': treat replacement as a string to pass to the current engine
  -- * 'lua': treat replacement as lua function body where search match is identified by `match` and
  --          meta variables (with astgrep for example) are available in `vars` table (e.g. `vars.A` captures `$A`)
  -- * 'vimscript': treat replacement as vimscript function body where search match is identified by `match` and
  --          meta variables (with astgrep for example) are available in `vars` table (e.g. `vars.A` captures `$A`)
  enabledReplacementInterpreters = { 'default', 'lua', 'vimscript' },

  -- which replacement interprer to use
  -- Must be one of enabledReplacementInterpreters defined above.
  replacementInterpreter = 'default',

  -- specifies the command to run (with `vim.cmd(...)`) in order to create
  -- the window in which the grug-far buffer will appear
  -- ex (horizontal bottom right split): 'botright split'
  -- ex (open new tab): 'tab split'
  windowCreationCommand = 'vsplit',

  -- buffer line numbers + match line numbers can get a bit visually overwhelming
  -- turn this off if you still like to see the line numbers
  disableBufferLineNumbers = true,

  -- help line config
  helpLine = {
    -- whether to show the help line at the top of the buffer
    enabled = true,
  },

  -- maximum number of search chars to show in buffer and quickfix list titles
  -- zero disables showing it
  maxSearchCharsInTitles = 30,

  -- static title to use for grug-far buffer, as opposed to the dynamically generated title.
  -- Note that nvim does not allow multiple buffers with the same name, so this option is meant more
  -- as something to be specified for a particular instance as opposed to something set in the setup function
  -- nil or '' disables it
  staticTitle = nil,

  -- whether to start in insert mode,
  -- set to false for normal mode
  startInInsertMode = true,

  -- row in the window to position the cursor at at start
  startCursorRow = 2,

  -- whether to wrap text in the grug-far buffer
  wrap = true,

  -- whether or not to make a transient buffer which is both unlisted and fully deletes itself when not in use
  transient = false,

  -- by default, in visual mode, the visual selection is used to prefill the search
  -- setting this option to true disables that behaviour
  -- deprecated, please use visualSelectionUsage instead
  ignoreVisualSelection = false,

  -- how to treat current visual selection when grug-far is invoked
  -- prefill-search - use to prefill "search string"
  -- operate-within-range - use as buffer range to operate within
  -- ignore - ignore/discard visual selection
  visualSelectionUsage = 'prefill-search',

  -- shortcuts for the actions you see at the top of the buffer
  -- set to '' or false to unset. Mappings with no normal mode value will be removed from the help header
  -- you can specify either a string which is then used as the mapping for both normal and insert mode
  -- or you can specify a table of the form { [mode] = <lhs> } (e.g. { i = '<C-enter>', n = '<localleader>gr'})
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
    openLocation = { n = '<localleader>o' },
    openNextLocation = { n = '<down>' },
    openPrevLocation = { n = '<up>' },
    gotoLocation = { n = '<enter>' },
    pickHistoryEntry = { n = '<enter>' },
    abort = { n = '<localleader>b' },
    help = { n = 'g?' },
    toggleShowCommand = { n = '<localleader>p' },
    swapEngine = { n = '<localleader>e' },
    previewLocation = { n = '<localleader>i' },
    swapReplacementInterpreter = { n = '<localleader>x' },
    applyNext = { n = '<localleader>j' },
    applyPrev = { n = '<localleader>k' },
    nextInput = { n = '<tab>' },
    prevInput = { n = '<s-tab>' },
  },

  -- separator between inputs and results, default depends on nerdfont
  resultsSeparatorLineChar = '',

  -- highlight the results with TreeSitter, if available
  resultsHighlight = true,

  -- highlight the inputs with TreeSitter, if available
  inputsHighlight = true,

  -- constructor for label shown on left side of match lines,
  -- used to display line (and column) numbers
  -- should return a list of `[text, highlight]` tuples
  -- see LineNumberLabelType below for more type details
  lineNumberLabel = function(params, options)
    local width = math.max(params.max_line_number_length, 3)
    local lineNumbersEllipsis = options.icons.enabled and options.icons.lineNumbersEllipsis or ' '
    return {
      {
        params.line_number and ('%' .. width .. 's '):format(params.line_number)
          or (
            (' '):rep(width - vim.fn.strdisplaywidth(lineNumbersEllipsis)) -- to support multi-byte utf-8 chars
            .. lineNumbersEllipsis
            .. ' '
          ),
        params.is_current_line and 'GrugFarResultsCursorLineNo' or 'GrugFarResultsLineNr',
      },
    }
  end,

  -- long file paths can sometimes be annoying to work with if wrap is not on and they get cut off by the window.
  -- this option allows you to function which will returns a 0-based range for the part of the file path
  -- that will be concealed. If nil values are returned by the function, no concealing is done.
  -- see FilePathConcealType below for more type details
  -- If option is set to false, no concealing will happen
  -- if option wrap=true, this option has no effect
  filePathConceal = function(params)
    local len = #params.file_path
    local window_width = params.window_width - 8 -- note: that last bit accounts for sign column, conceal char, etc.
    if len < params.window_width then
      return
    end

    local first_part_len = math.floor(window_width / 3)
    local delta = len - window_width

    return first_part_len, first_part_len + delta
  end,

  -- character used as a replacement for the part of the file path that is concealed
  filePathConcealChar = '…',

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

  -- icons for UI, default ones depend on nerdfont
  -- set individual ones to '' to disable, or set enabled = false for complete disable
  icons = {
    -- whether to show icons
    enabled = true,

    -- provider to use for file icons
    -- acceptable values: 'first_available', 'nvim-web-devicons', 'mini.icons', false (to disable)
    fileIconsProvider = 'first_available',

    actionEntryBullet = ' ',

    searchInput = ' ',
    replaceInput = ' ',
    filesFilterInput = ' ',
    flagsInput = '󰮚 ',
    pathsInput = ' ',

    resultsStatusReady = '󱩾 ',
    resultsStatusError = ' ',
    resultsStatusSuccess = '󰗡 ',
    resultsActionMessage = '  ',
    resultsEngineLeft = '⟪',
    resultsEngineRight = '⟫',
    resultsChangeIndicator = '┃',
    resultsAddedIndicator = '▒',
    resultsRemovedIndicator = '▒',
    resultsDiffSeparatorIndicator = '┊',
    historyTitle = '   ',
    helpTitle = ' 󰘥  ',
    lineNumbersEllipsis = ' ',

    newline = ' ',
  },

  -- strings to auto-fill in each input area at start
  -- those are not necessarily useful as global defaults but quite useful as overrides
  -- when launching through the lua API. For example, this is how you would launch grug-far.nvim
  -- with the current word under the cursor as the search string
  --
  -- require('grug-far').open({ prefills = { search = vim.fn.expand("<cword>") } })
  --
  prefills = {
    search = nil,
    replacement = nil,
    filesFilter = nil,
    flags = nil,
    paths = nil,
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

  -- unique instance name. This is used as a handle to refer to a particular instance of grug-far when
  -- toggling visibility, etc.
  -- As this needs to be unique per instance, this option is meant to be specified for a particular instance
  -- as opposed to something set in the setup function
  instanceName = nil,

  -- folding related options
  folding = {
    -- whether to enable folding
    enabled = true,

    -- sets foldlevel, folds with higher level will be closed.
    -- result matche lines for each file have fold level 1
    -- set it to 0 if you would like to have the results initially collapsed
    -- See :h foldlevel
    foldlevel = 1,

    -- visual indicator of folds, see :h foldcolumn
    -- set to '0' to disable
    foldcolumn = '1',
  },

  -- options related to locations in results list
  resultLocation = {
    -- whether to show the result location number label
    -- this can be useful for example if you would like to use that number
    -- as a count to goto directly to a result
    -- (for instance `3<enter>` would goto the third result's location)
    showNumberLabel = true,

    -- position of the number when visible, acceptable values are:
    -- 'right_align', 'eol' and 'inline'
    numberLabelPosition = 'right_align',

    -- format for the number label, by default it displays as for example:  [42]
    numberLabelFormat = ' [%d]',
  },

  -- options related to the target window for goto or open actions
  openTargetWindow = {
    -- filter for windows to exclude when considering candidate targets. It's a list of either:
    -- * filetype to exclude
    -- * filter function of the form: function(winid: number): boolean (return true to exclude)
    exclude = {},

    -- preferred location for target window relative to the grug-far window. If an existing candidate
    -- window that is not excluded by the exclude filter exists in that direction, it will be reused,
    -- otherwise a new window will be created in that direction.
    -- available options: "prev" | "left" | "right" | "above" | "below"
    preferredLocation = 'left',
  },

  -- options for help window, history window and preview windows
  -- these are the same options as the ones that get passed to
  -- `vim.api.nvim_open_win()`: border, style, etc.
  -- see :h nvim_open_win for more info
  helpWindow = {},
  historyWindow = {},
  previewWindow = {},
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
---@field openLocation KeymapDef
---@field openNextLocation KeymapDef
---@field openPrevLocation KeymapDef
---@field pickHistoryEntry KeymapDef
---@field toggleShowCommand KeymapDef
---@field abort KeymapDef
---@field help KeymapDef
---@field swapEngine KeymapDef
---@field previewLocation KeymapDef
---@field swapReplacementInterpreter KeymapDef
---@field applyNext KeymapDef
---@field applyPrev KeymapDef
---@field nextInput KeymapDef
---@field prevInput KeymapDef

---@class KeymapsOverride
---@field replace? KeymapDef
---@field qflist? KeymapDef
---@field syncLocations? KeymapDef
---@field historyAdd? KeymapDef
---@field historyOpen? KeymapDef
---@field refresh? KeymapDef
---@field syncLine? KeymapDef
---@field close? KeymapDef
---@field open? KeymapDef
---@field gotoLocation? KeymapDef
---@field openLocation? KeymapDef
---@field openNextLocation? KeymapDef
---@field openPrevLocation? KeymapDef
---@field pickHistoryEntry? KeymapDef
---@field toggleShowCommand? KeymapDef
---@field abort? KeymapDef
---@field help? KeymapDef
---@field swapEngine? KeymapDef
---@field previewLocation? KeymapDef
---@field swapReplacementInterpreter? KeymapDef
---@field applyNext? KeymapDef
---@field applyPrev? KeymapDef
---@field nextInput? KeymapDef
---@field prevInput? KeymapDef

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

---@alias FileIconsProviderType "first_available" | "mini.icons" |  "nvim-web-devicons" | false

---@class IconsTable
---@field enabled boolean
---@field fileIconsProvider FileIconsProviderType
---@field searchInput string
---@field actionEntryBullet string
---@field replaceInput string
---@field filesFilterInput string
---@field flagsInput string
---@field resultsStatusReady string
---@field resultsStatusError string
---@field resultsStatusSuccess string
---@field resultsActionMessage string
---@field resultsChangeIndicator string
---@field resultsAddedIndicator string
---@field resultsRemovedIndicator string
---@field resultsDiffSeparatorIndicator string
---@field historyTitle string
---@field helpTitle string
---@field lineNumbersEllipsis string
---@field newline string

---@class IconsTableOverride
---@field enabled? boolean
---@field fileIconsProvider? FileIconsProviderType
---@field searchInput? string
---@field actionEntryBullet? string
---@field replaceInput? string
---@field filesFilterInput? string
---@field flagsInput? string
---@field resultsStatusReady? string
---@field resultsStatusError? string
---@field resultsStatusSuccess? string
---@field resultsActionMessage? string
---@field resultsChangeIndicator? string
---@field resultsAddedIndicator? string
---@field resultsRemovedIndicator? string
---@field resultsDiffSeparatorIndicator? string
---@field historyTitle? string
---@field helpTitle? string
---@field lineNumbersEllipsis? string
---@field newline? string

---@class PlaceholdersTable
---@field enabled? boolean
---@field search? string
---@field rules? string
---@field replacement? string
---@field replacement_lua? string
---@field filesFilter? string
---@field flags? string
---@field paths? string

---@alias LanguageGlobsTable table<string, string[]>

---@class GrugFarPrefills
---@field search? string
---@field rules? string
---@field replacement? string
---@field filesFilter? string
---@field flags? string
---@field paths? string

---@class FoldingTable
---@field enabled boolean
---@field foldlevel integer
---@field foldcolumn string

---@class FoldingTableOverride
---@field enabled? boolean
---@field foldlevel? integer
---@field foldcolumn? string | integer

---@class RipgrepEngineTable
---@field path string
---@field extraArgs string
---@field showReplaceDiff boolean
---@field placeholders PlaceholdersTable

---@class RipgrepEngineTableOverride
---@field path? string
---@field extraArgs? string
---@field showReplaceDiff? boolean
---@field placeholders? PlaceholdersTable

---@class AstgrepEngineTable
---@field path string
---@field extraArgs string
---@field placeholders PlaceholdersTable

---@class AstgrepRulesEngineTable
---@field path string
---@field extraArgs string
---@field placeholders PlaceholdersTable
---@field languageGlobs LanguageGlobsTable

---@class AstgrepEngineTableOverride
---@field path? string
---@field extraArgs? string
---@field placeholders? PlaceholdersTable

---@class AstgrepRulesEngineTableOverride
---@field path? string
---@field extraArgs? string
---@field placeholders? PlaceholdersTable
---@field languageGlobs? LanguageGlobsTable

---@class EnginesTable
---@field ripgrep RipgrepEngineTable
---@field astgrep AstgrepEngineTable
---@field astgrep-rules AstgrepRulesEngineTable

---@class EnginesTableOverride
---@field ripgrep? RipgrepEngineTableOverride
---@field astgrep? AstgrepEngineTableOverride
---@field astgrep-rules? AstgrepRulesEngineTableOverride

---@alias GrugFarEngineType "ripgrep" | "astgrep" | "astgrep-rules"
---@alias GrugFarReplacementInterpreterType "lua" | "vimscript" | "default"

---@alias NumberLabelPosition "right_align" | "eol" | "inline"

---@class ResultLocationTable
---@field showNumberLabel boolean
---@field numberLabelPosition NumberLabelPosition
---@field numberLabelFormat string

---@class ResultLocationTableOverride
---@field showNumberLabel? boolean
---@field numberLabelPosition? NumberLabelPosition
---@field numberLabelFormat? string

---@class HelpLineTable
---@field enabled boolean

---@class HelpLineTableOverride
---@field enabled? boolean

---@alias FilterWindowFn fun(winid: number): boolean
---@alias WinPreferredLocation "prev" | "left" | "right" | "above" | "below"

---@class OpenTargetWindowTable
---@field exclude (string | FilterWindowFn)[]
---@field preferredLocation WinPreferredLocation

---@class OpenTargetWindowTableOverride
---@field exclude? (string | FilterWindowFn)[]
---@field preferredLocation? WinPreferredLocation

---@alias VisualSelectionUsageType 'prefill-search' | 'operate-within-range' | 'ignore'

---@class LineNumberLabelParams
---@field line_number integer?
---@field column_number integer?
---@field max_line_number_length integer
---@field max_column_number_length integer
---@field is_context boolean?
---@field is_current_line boolean?

---@alias LineNumberLabelType fun(params: LineNumberLabelParams, options: GrugFarOptions): string[][] list of `[text, highlight]` tuples

---@class FilePathConcealParams
---@field file_path string
---@field window_width integer

---@alias FilePathConcealType fun(params: FilePathConcealParams): (start_col: integer?, end_col: integer?)

---@class GrugFarOptions
---@field debounceMs integer
---@field minSearchChars integer
---@field maxSearchMatches integer?
---@field maxLineLength integer
---@field breakindentopt string
---@field searchOnInsertLeave boolean
---@field normalModeSearch boolean
---@field maxWorkers integer
---@field rgPath string
---@field extraRgArgs string
---@field windowCreationCommand string
---@field disableBufferLineNumbers boolean
---@field maxSearchCharsInTitles integer
---@field staticTitle? string
---@field startInInsertMode boolean
---@field startCursorRow integer
---@field wrap boolean
---@field transient boolean
---@field ignoreVisualSelection boolean
---@field visualSelectionUsage VisualSelectionUsageType
---@field keymaps Keymaps
---@field resultsSeparatorLineChar string
---@field resultsHighlight boolean
---@field inputsHighlight boolean
---@field lineNumberLabel LineNumberLabelType
---@field filePathConceal FilePathConcealType
---@field spinnerStates string[] | false
---@field filePathConcealChar string
---@field reportDuration boolean
---@field icons IconsTable
---@field prefills GrugFarPrefills
---@field history HistoryTable
---@field instanceName? string
---@field folding FoldingTable
---@field engines EnginesTable
---@field enabledEngines string[]
---@field engine GrugFarEngineType
---@field replacementInterpreter GrugFarReplacementInterpreterType
---@field enabledReplacementInterpreters GrugFarReplacementInterpreterType[]
---@field resultLocation ResultLocationTable
---@field openTargetWindow OpenTargetWindowTable
---@field helpLine HelpLineTable
---@field helpWindow vim.api.keyset.win_config
---@field historyWindow vim.api.keyset.win_config
---@field previewWindow vim.api.keyset.win_config

---@class GrugFarOptionsOverride
---@field debounceMs? integer
---@field minSearchChars? integer
---@field maxSearchMatches? integer
---@field maxLineLength? integer
---@field breakindentopt? string
---@field searchOnInsertLeave? boolean
---@field normalModeSearch? boolean
---@field maxWorkers? integer
---@field rgPath? string
---@field extraRgArgs? string
---@field windowCreationCommand? string
---@field disableBufferLineNumbers? boolean
---@field maxSearchCharsInTitles? integer
---@field staticTitle? string
---@field startInInsertMode? boolean
---@field startCursorRow? integer
---@field wrap? boolean
---@field transient? boolean
---@field ignoreVisualSelection? boolean
---@field visualSelectionUsage? VisualSelectionUsageType
---@field keymaps? KeymapsOverride
---@field resultsSeparatorLineChar? string
---@field resultsHighlight? boolean
---@field inputsHighlight? boolean
---@field lineNumberLabel? LineNumberLabelType
---@field filePathConceal? FilePathConcealType
---@field spinnerStates? string[] | false
---@field filePathConcealChar? string
---@field reportDuration? boolean
---@field icons? IconsTableOverride
---@field prefills? GrugFarPrefills
---@field history? HistoryTableOverride
---@field instanceName? string
---@field folding? FoldingTableOverride
---@field engines? EnginesTableOverride
---@field engine? GrugFarEngineType
---@field replacementInterpreter? GrugFarReplacementInterpreterType
---@field enabledReplacementInterpreters? GrugFarReplacementInterpreterType[]
---@field resultLocation? ResultLocationTableOverride
---@field openTargetWindow? OpenTargetWindowTableOverride
---@field helpLine? HelpLineTableOverride
---@field helpWindow? vim.api.keyset.win_config
---@field historyWindow? vim.api.keyset.win_config
---@field previewWindow? vim.api.keyset.win_config

--- generates merged options
---@param options GrugFarOptionsOverride | GrugFarOptions
---@param defaults GrugFarOptions
---@return GrugFarOptions
function M.with_defaults(options, defaults)
  local newOptions = vim.tbl_deep_extend('force', vim.deepcopy(defaults), options)

  -- normalize keymaps opts
  for key, value in pairs(newOptions.keymaps) do
    if not value or value == '' then
      newOptions.keymaps[key] = {}
    end

    if type(value) == 'string' then
      newOptions.keymaps[key] = { i = value, n = value }
    end
  end

  if options.rgPath then
    vim.deprecate('options.rgPath', 'options.engines.ripgrep.path', 'soon', 'grug-far.nvim')
    newOptions.engines.ripgrep.path = options.rgPath
  end

  if not options.normalModeSearch and options.searchOnInsertLeave then
    vim.deprecate(
      'options.searchOnInsertLeave',
      'options.normalModeSearch',
      'soon',
      'grug-far.nvim'
    )
    newOptions.normalModeSearch = options.searchOnInsertLeave
  end

  if options['placeholders'] then
    error(
      'options.placeholders has been removed in favor of options.engines[engine].placeholders! Please use that one instead!'
    )
  end

  if
    not vim.tbl_contains(
      newOptions.enabledReplacementInterpreters,
      newOptions.replacementInterpreter
    )
  then
    error('options.enabledReplacementInterpreters must contain options.replacementInterpreter')
  end

  if options.extraRgArgs then
    vim.deprecate(
      'options.extraRgArgs',
      'options.engines.ripgrep.extraArgs',
      'soon',
      'grug-far.nvim'
    )
    newOptions.engines.ripgrep.extraArgs = options.extraRgArgs
  end

  if options.ignoreVisualSelection ~= nil then
    vim.deprecate(
      'options.ignoreVisualSelection',
      'options.visualSelectionUsage',
      'soon',
      'grug-far.nvim'
    )
    if options.ignoreVisualSelection == true then
      newOptions.visualSelectionUsage = 'prefill-search'
    elseif options.ignoreVisualSelection == false then
      newOptions.visualSelectionUsage = 'ignore'
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

--- whether we should conceal
---@param options GrugFarOptions
function M.shouldConceal(options)
  return (not options.wrap) and options.filePathConceal
end

---@type GrugFarOptionsOverride?
local _globalOptionsOverride = nil

--- sets global opts override
---@param options GrugFarOptionsOverride?
function M.setGlobalOptionsOverride(options)
  _globalOptionsOverride = options
end

--- gets global opts
---@return GrugFarOptions
function M.getGlobalOptions()
  return M.with_defaults(_globalOptionsOverride or vim.g.grug_far or {}, M.defaultOptions)
end

return M
