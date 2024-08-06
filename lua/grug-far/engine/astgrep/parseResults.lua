local utils = require('grug-far/utils')
local engine = require('grug-far/engine')
local ResultHighlightType = engine.ResultHighlightType

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

---@class AstgrepMatchOffset
---@field start integer
---@field end integer

---@class AstgrepMatchRange
---@field start AstgrepMatchPos
---@field end AstgrepMatchPos
---@field byteOffset AstgrepMatchOffset

---@class AstgrepMatch
---@field file string
---@field lines string
---@field text string
---@field replacement string
---@field range AstgrepMatchRange

--- adds result lines
---@param resultLines string[] lines to add
---@param range AstgrepMatchRange
---@param lines string[] lines table to add to
---@param highlights ResultHighlight[] highlights table to add to
---@param lineNumberSign ResultHighlightSign
---@param matchHighlightType ResultHighlightType
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
    local line_no = tostring(range.start.line + j - 1)
    local col_no = tostring(range.start.column + 1)
    local prefix = string.format('%-7s', line_no .. ':' .. col_no .. ':')

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
    table.insert(highlights, {
      hl_type = matchHighlightType,
      hl = HighlightByType[matchHighlightType],
      start_line = current_line,
      start_col = j == 1 and #prefix + range.start.column or #prefix,
      end_line = current_line,
      end_col = isLastLine and #prefix + range['end'].column or #resultLine,
    })

    table.insert(lines, utils.getLineWithoutCarriageReturn(resultLine))
  end
end

--- parse results data and get info
---@param matches AstgrepMatch[]
---@return ParsedResultsData
local function parseResults(matches)
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

    local lineNumberSign = match.replacement and removed_sign or change_sign
    local matchHighlightType = match.replacement and ResultHighlightType.MatchRemoved
      or ResultHighlightType.Match
    local matchLines = vim.split(match.lines, '\n')
    addResultLines(matchLines, match.range, lines, highlights, lineNumberSign, matchHighlightType)

    -- add replacements lines
    if match.replacement then
      local matchLinesStr = match.lines
      local matchStart = match.range.start.column + 1 -- column is zero-based
      local matchEnd = matchStart + #match.text - 1
      local prefix = matchLinesStr:sub(1, matchStart - 1)
      local postfix = matchLinesStr:sub(matchEnd + 1, -1)
      local replacedStr = prefix .. match.replacement .. postfix
      local replacedLines = vim.split(replacedStr, '\n')

      -- Note: a bit dirty to modify range data directly, but this is more efficient vs cloning as nothing
      -- else below this needs it
      match.range['end'].column = #replacedLines[#replacedLines] - #postfix
      addResultLines(
        replacedLines,
        match.range,
        lines,
        highlights,
        added_sign,
        ResultHighlightType.MatchAdded
      )
      if i ~= #matches then
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

return parseResults
