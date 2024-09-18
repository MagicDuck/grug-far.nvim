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

---@class AstgrepMatchByteOffset
---@field start integer
---@field end integer

---@class AstgrepMatchRange
---@field start AstgrepMatchPos
---@field end AstgrepMatchPos
---@field byteOffset AstgrepMatchByteOffset

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
  local trailingStr = trailing > 0 and lines:sub(-trailing, -1) or ''

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
      or (#match.lines - #match.text - leading)

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

      local replaceRange = vim.deepcopy(match.range)
      replaceRange['end'].column = #replacedLines[#replacedLines] - #postfix
      addResultLines(
        replacedLines,
        replaceRange,
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

--- decodes streamed json matches, appending to given table
---@param matches AstgrepMatch[]
---@param data string
---@param eval_fn? fun(...): string
function M.json_decode_matches(matches, data, eval_fn)
  local json_lines = vim.split(data, '\n')
  for _, json_line in ipairs(json_lines) do
    if #json_line > 0 then
      local match = vim.json.decode(json_line)
      if eval_fn then
        -- TODO (sbadragan): pass in meta variables?
        match.replacement = eval_fn(match.text)
      end
      table.insert(matches, match)
    end
  end
end

--- splits off matches corresponding to the last file
---@param matches AstgrepMatch[]
---@return AstgrepMatch[] before, AstgrepMatch[] after
function M.split_last_file_matches(matches)
  local end_index = 0
  for i = #matches - 1, 1, -1 do
    if matches[i].file ~= matches[i + 1].file then
      end_index = i
      break
    end
  end

  local before = {}
  for i = 1, end_index do
    table.insert(before, matches[i])
  end
  local after = {}
  for i = end_index + 1, #matches do
    table.insert(after, matches[i])
  end

  return before, after
end

--- splits off matches corresponding to each file
---@param matches AstgrepMatch[]
---@return AstgrepMatch[][] matches_per_file
function M.split_matches_per_file(matches)
  if #matches == 0 then
    return {}
  end

  local matches_per_file = { { matches[1] } }
  for i = 2, #matches, 1 do
    if matches[i].file == matches[i - 1].file then
      table.insert(matches_per_file[#matches_per_file], matches[i])
    else
      table.insert(matches_per_file, { matches[i] })
    end
  end

  return matches_per_file
end

--- constructs new file content, given old file content and matches with replacements
---@param contents string
---@param matches AstgrepMatch[]
---@return string new_contents
function M.getReplacedContents(contents, matches)
  local new_contents = ''
  local last_index = 0
  for _, match in ipairs(matches) do
    new_contents = new_contents
      .. contents:sub(last_index + 1, match.range.byteOffset.start)
      .. match.replacement

    last_index = match.range.byteOffset['end']
  end
  if last_index < #contents then
    new_contents = new_contents .. contents:sub(last_index + 1)
  end

  return new_contents
end

return M
