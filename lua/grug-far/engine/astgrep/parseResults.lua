local utils = require('grug-far/utils')
local engine = require('grug-far/engine')
local ResultHighlightType = engine.ResultHighlightType

local M = {}

---@type ResultHighlightSign
local change_sign = { icon = 'resultsChangeIndicator', hl = 'GrugFarResultsChangeIndicator' }
---@type ResultHighlightSign
local removed_sign = { icon = 'resultsRemovedIndicator', hl = 'GrugFarResultsRemoveIndicator' }
---@type ResultHighlightSign
local added_sign = { icon = 'resultsAddedIndicator', hl = 'GrugFarResultsAddIndicator' }
---@type ResultHighlightSign
local separator_sign =
  { icon = 'resultsDiffSeparatorIndicator', hl = 'GrugFarResultsDiffSeparatorIndicator' }

local HighlightByType = {
  [ResultHighlightType.LineNumber] = 'GrugFarResultsLineNo',
  [ResultHighlightType.ColumnNumber] = 'GrugFarResultsLineColumn',
  [ResultHighlightType.FilePath] = 'GrugFarResultsPath',
  [ResultHighlightType.Match] = 'GrugFarResultsMatch',
  [ResultHighlightType.MatchAdded] = 'GrugFarResultsMatchAdded',
  [ResultHighlightType.MatchRemoved] = 'GrugFarResultsMatchRemoved',
  [ResultHighlightType.DiffSeparator] = 'Normal',
}

---@class AstgrepMatchPos
---@field line integer
---@field column integer

---@class AstgrepMatchRange
---@field start AstgrepMatchPos
---@field end AstgrepMatchPos

---@class AstgrepMatchCharCount
---@field leading integer
---@field trailing integer

---@class AstgrepMatch
---@field file string
---@field lines string
---@field text string
---@field replacement string
---@field range AstgrepMatchRange
---@field charCount? AstgrepMatchCharCount

--- adds result lines
---@param resultLines string[] lines to add
---@param range AstgrepMatchRange
---@param lines string[] lines table to add to
---@param highlights ResultHighlight[] highlights table to add to
---@param lineNumberSign? ResultHighlightSign
---@param matchHighlightType? ResultHighlightType
local function addResultLines(
  resultLines,
  range,
  lines,
  highlights,
  lineNumberSign,
  matchHighlightType
)
  local numlines = #lines
  for j, resultLine in ipairs(resultLines) do
    local current_line = numlines + j - 1
    local isLastLine = j == #resultLines
    local line_no = tostring(range.start.line + j)
    local col_no = range.start.column and tostring(range.start.column + 1) or nil
    local prefix = string.format('%-7s', line_no .. (col_no and ':' .. col_no .. ':' or '-'))

    table.insert(highlights, {
      hl_type = ResultHighlightType.LineNumber,
      hl = HighlightByType[ResultHighlightType.LineNumber],
      start_line = current_line,
      start_col = 0,
      end_line = current_line,
      end_col = #line_no,
      sign = lineNumberSign,
    })
    if col_no then
      table.insert(highlights, {
        hl_type = ResultHighlightType.ColumnNumber,
        hl = HighlightByType[ResultHighlightType.ColumnNumber],
        start_line = current_line,
        start_col = #line_no + 1, -- skip ':'
        end_line = current_line,
        end_col = #line_no + 1 + #col_no,
      })
    end

    resultLine = prefix .. resultLine
    if matchHighlightType then
      table.insert(highlights, {
        hl_type = matchHighlightType,
        hl = HighlightByType[matchHighlightType],
        start_line = current_line,
        start_col = j == 1 and #prefix + range.start.column or #prefix,
        end_line = current_line,
        end_col = isLastLine and #prefix + range['end'].column or #resultLine,
      })
    end

    table.insert(lines, utils.getLineWithoutCarriageReturn(resultLine))
  end
end

function M.splitMatchLines(lines, leading, trailing)
  local leadingStr = lines:sub(1, leading)
  local trailingStr = lines:sub(-trailing, -1)

  local last_leading_newline = utils.strFindLast(leadingStr, '\n')
  local leadingLines = last_leading_newline and leadingStr:sub(1, last_leading_newline - 1) or ''

  local first_trailing_newline = string.find(trailingStr, '\n', 1, true)
  local trailingLines = first_trailing_newline and trailingStr:sub(first_trailing_newline + 1, -1)
    or ''

  local matchLines = lines:sub(
    last_leading_newline and #leadingLines + 2 or 1,
    first_trailing_newline and -#trailingLines - 2 or -1
  )

  return leadingLines, matchLines, trailingLines
end

--- parse results data and get info
---@param matches AstgrepMatch[]
---@return ParsedResultsData
function M.parseResults(matches)
  local stats = { files = 0, matches = 0 }
  local lines = {}
  local highlights = {}

  for i = 1, #matches, 1 do
    local match = matches[i]
    stats.matches = stats.matches + 1
    local isFileBoundary = i == 1 or match.file ~= matches[i - 1].file

    if isFileBoundary and i > 1 then
      table.insert(lines, '')
    end

    if isFileBoundary then
      stats.files = stats.files + 1
      table.insert(highlights, {
        hl_type = ResultHighlightType.FilePath,
        hl = HighlightByType[ResultHighlightType.FilePath],
        start_line = #lines,
        start_col = 0,
        end_line = #lines,
        end_col = #match.file,
      })
      table.insert(lines, match.file)
    end

    local leading = match.charCount and match.charCount.leading or match.range.start.column
    local trailing = match.charCount and match.charCount.trailing
      or (#match.lines - match.range.start.column - #match.text)

    local leadingLinesStr, matchLinesStr, trailingLinesStr =
      M.splitMatchLines(match.lines, leading, trailing)

    -- add leading lines
    if #leadingLinesStr > 0 then
      local leadingLines = vim.split(leadingLinesStr, '\n')
      local leadingRange = vim.deepcopy(match.range)
      leadingRange.start.column = nil
      leadingRange.start.line = match.range.start.line - #leadingLines
      addResultLines(leadingLines, leadingRange, lines, highlights, change_sign)
    end

    -- add match lines
    local lineNumberSign = match.replacement and removed_sign or change_sign
    local matchHighlightType = match.replacement and ResultHighlightType.MatchRemoved
      or ResultHighlightType.Match
    local matchLines = vim.split(matchLinesStr, '\n')
    addResultLines(matchLines, match.range, lines, highlights, lineNumberSign, matchHighlightType)

    -- add replacements lines
    if match.replacement then
      local matchStart = match.range.start.column + 1 -- column is zero-based
      local matchEnd = matchStart + #match.text - 1
      local prefix = matchLinesStr:sub(1, matchStart - 1)
      local postfix = matchLinesStr:sub(matchEnd + 1, -1)
      local replacedStr = prefix .. match.replacement .. postfix
      local replacedLines = vim.split(replacedStr, '\n')

      -- Note: a bit dirty to modify range data directly, but this is more efficient vs cloning as nothing
      -- else below this needs it
      local replaceRange = vim.deepcopy(match.range)
      replaceRange['end'].column = #replacedLines[#replacedLines] - #postfix
      addResultLines(
        replacedLines,
        match.range,
        lines,
        highlights,
        added_sign,
        ResultHighlightType.MatchAdded
      )
    end

    -- add trailing lines
    if #trailingLinesStr > 0 then
      local trailingLines = vim.split(trailingLinesStr, '\n')
      local trailingRange = vim.deepcopy(match.range)
      trailingRange.start.column = nil
      trailingRange.start.line = match.range['end'].line + 1
      addResultLines(trailingLines, trailingRange, lines, highlights, change_sign)
    end

    -- add separator
    if
      (match.replacement or #leadingLinesStr > 0 or #trailingLinesStr > 0)
      and i ~= #matches
      and match.file == matches[i + 1].file
    then
      table.insert(highlights, {
        hl_type = ResultHighlightType.DiffSeparator,
        hl = HighlightByType[ResultHighlightType.DiffSeparator],
        start_line = #lines,
        start_col = 1,
        end_line = #lines,
        end_col = 1,
        sign = separator_sign,
      })
      table.insert(lines, engine.DiffSeparatorChars)
    end

    if i == #matches then
      table.insert(lines, '')
    end
  end

  return {
    lines = lines,
    highlights = highlights,
    stats = stats,
  }
end

return M
