local renderHelp = require('grug-far/render/help')
local renderInput = require('grug-far/render/input')
local renderResults = require('grug-far/render/results')
local utils = require('grug-far/utils')

local TOP_EMPTY_LINES = 2
local BEFORE_RESULTS_LINES = 2

---@param buf integer
---@param context GrugFarContext
local function render(buf, context)
  local inputs = context.state.inputs
  local placeholders = context.options.placeholders
  local keymaps = context.options.keymaps

  local lineNr = 0
  utils.ensureBufTopEmptyLines(buf, TOP_EMPTY_LINES)
  renderHelp({
    buf = buf,
    extmarkName = 'farHelp',
    actions = {
      { text = 'Actions / Help', keymap = keymaps.help, description = 'Open up help window.' },
      {
        text = 'Replace',
        keymap = keymaps.replace,
        description = "Perform replace. Note that compared to 'Sync All', replace can also handle multiline replacements.",
      },
      {
        text = 'Sync All',
        keymap = keymaps.syncLocations,
        description = 'Sync all result lines text back to their originating files. Deleting lines and manually modifying lines text will affect the result.',
      },
      {
        text = 'Sync Line',
        keymap = keymaps.syncLine,
        description = "Sync current result line text back to its originating file. Manually modifying the line's text will affect the result.",
      },
      {
        text = 'History Open',
        keymap = keymaps.historyOpen,
        description = 'Open history window. The history window allows you to select and edit historical searches/replacements.',
      },
      {
        text = 'History Add',
        keymap = keymaps.historyAdd,
        description = 'Add current search/replace as a history entry.',
      },
      {
        text = 'Refresh',
        keymap = keymaps.refresh,
        description = 'Re-trigger search. This can be useful in situations where files have been changed externally for example.',
      },
      {
        text = 'Goto',
        keymap = keymaps.gotoLocation,
        description = "When cursor is placed on a result file path, go to that file. When it's placed over a result line, go to the file/line/column of the match.",
      },
      {
        text = 'Open',
        keymap = keymaps.openLocation,
        description = "Same as 'Goto', but cursor stays in grug-far buffer. This can allow a quicker thumb-through result locations. Alternatively, you can use the '--context <num>' flag to see match contexts.",
      },
      {
        text = 'Quickfix',
        keymap = keymaps.qflist,
        description = 'Sends result lines to the quickfix list. Deleting result lines will cause them not to be included. ',
      },
      {
        text = 'Abort',
        keymap = keymaps.abort,
        description = "Abort current operation. Can be useful if you've ended up doing too large of a search or if you've changed your mind about a replacement.",
      },
      {
        text = 'Close',
        keymap = keymaps.close,
        description = 'Close grug-far buffer/window. This is the same as `:bd` except that it will also ask you to confirm if there is a replace/sync in progress, as those would be aborted.',
      },
    },
  }, context)

  lineNr = lineNr + TOP_EMPTY_LINES
  inputs.search = renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = 'search',
    icon = 'searchInput',
    label = 'Search:',
    placeholder = placeholders.enabled and placeholders.search,
  }, context)

  lineNr = lineNr + 1
  inputs.replacement = renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = 'replace',
    icon = 'replaceInput',
    label = 'Replace:',
    placeholder = placeholders.enabled and placeholders.replacement,
  }, context)

  lineNr = lineNr + 1
  inputs.filesFilter = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = 'files_glob',
    icon = 'filesFilterInput',
    label = 'Files Filter:',
    placeholder = placeholders.enabled and placeholders.filesFilter,
  }, context))

  lineNr = lineNr + 1
  inputs.flags = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = 'flags',
    icon = 'flagsInput',
    label = 'Flags:',
    placeholder = placeholders.enabled and placeholders.flags,
  }, context))

  lineNr = lineNr + BEFORE_RESULTS_LINES
  renderResults({
    buf = buf,
    minLineNr = lineNr,
  }, context)
end

return render
