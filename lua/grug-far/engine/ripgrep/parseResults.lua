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

---@class RipgrepJsonSubmatch
---@field match {text: string}
---@field replacement {text: string}
---@field start integer
---@field end integer

---@class RipgrepJsonMatchData
---@field lines { text: string}
---@field line_number integer
---@field absolute_offset integer
---@field submatches RipgrepJsonSubmatch[]

---@class RipgrepJsonMatch
---@field type "match"
---@field data RipgrepJsonMatchData

---@class RipgrepJsonMatchContext
---@field type "context"
---@field data RipgrepJsonMatchData

---@class RipgrepJsonMatchBegin
---@field type "begin"
---@field data { path: { text: string } }

---@class RipgrepJsonMatchEnd
---@field type "end"
---@field data { path: { text: string } }
-- note: this one has more stats things, but we don't care about them, atm.

---@class RipgrepJsonMatchSummary
---@field type "summary"
-- note: this one has more stats things, but we don't care about them, atm.

---@alias RipgrepJson RipgrepJsonMatchSummary | RipgrepJsonMatchBegin | RipgrepJsonMatchEnd | RipgrepJsonMatch | RipgrepJsonMatchContext

--- adds result lines
---@param resultLines string[] lines to add
---@param range { start: { column: integer?, line: integer}, end: {column: integer?, line: integer}}
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

--- parse results data and get info
---@param matches RipgrepJson[]
---@param isSearchWithReplace boolean
---@param showDiff boolean
---@return ParsedResultsData
function M.parseResults(matches, isSearchWithReplace, showDiff)
  local stats = { files = 0, matches = 0 }
  local lines = {}
  local highlights = {}

  local last_line_number = nil
  for _, match in ipairs(matches) do
    local data = match.data

    -- add separator
    if
      last_line_number
      and isSearchWithReplace
      and showDiff
      and (match.type == 'match' or match.type == 'context')
      and last_line_number < data.line_number - 1
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
      last_line_number = nil
    end

    if match.type == 'begin' then
      stats.files = stats.files + 1
      table.insert(highlights, {
        hl_type = ResultHighlightType.FilePath,
        hl = HighlightByType[ResultHighlightType.FilePath],
        start_line = #lines,
        start_col = 0,
        end_line = #lines,
        end_col = #data.path.text,
      })
      table.insert(lines, data.path.text)
    elseif match.type == 'end' then
      last_line_number = nil
      table.insert(lines, '')
    elseif match.type == 'match' then
      stats.matches = stats.matches + 1
      local first_submatch = data.submatches[1]
      local last_submatch = data.submatches[#data.submatches]
      local match_lines_text = data.lines.text:sub(1, -2) -- strip trailing newline
      local match_lines = vim.split(match_lines_text, '\n')
      last_line_number = data.line_number + #match_lines - 1

      -- add match lines
      if not isSearchWithReplace or (isSearchWithReplace and showDiff) then
        local lineNumberSign = (isSearchWithReplace and showDiff) and removed_sign or nil
        local matchHighlightType = (isSearchWithReplace and showDiff)
            and ResultHighlightType.MatchRemoved
          or ResultHighlightType.Match
        addResultLines(match_lines, {
          start = {
            line = data.line_number,
            column = first_submatch and first_submatch.start or nil,
          },
          ['end'] = {
            line = last_line_number,
            column = last_submatch and last_submatch['end'] or nil,
          },
        }, lines, highlights, lineNumberSign, matchHighlightType)
      end

      -- add replacement lines
      if isSearchWithReplace then
        -- build lines text with replacements spliced in for matches
        local last_index = 0
        local replaced_lines_text = ''
        for _, submatch in ipairs(data.submatches) do
          replaced_lines_text = replaced_lines_text
            .. match_lines_text:sub(last_index + 1, submatch.start)
            .. submatch.replacement.text
          last_index = submatch['end']
        end
        if last_index < #match_lines_text then
          replaced_lines_text = replaced_lines_text .. match_lines_text:sub(last_index + 1)
        end

        local replaced_lines = vim.split(replaced_lines_text, '\n')

        addResultLines(replaced_lines, {
          start = {
            line = data.line_number,
            column = first_submatch and first_submatch.start or nil,
          },
          ['end'] = {
            line = data.line_number + #replaced_lines - 1,
            column = last_submatch
                and #replaced_lines[#replaced_lines] - (#match_lines_text - last_submatch['end'])
              or nil,
          },
        }, lines, highlights, added_sign, ResultHighlightType.MatchAdded)
      end
    elseif match.type == 'context' then
      local context_lines_text = data.lines.text:sub(1, -2) -- strip trailing newline
      local context_lines = vim.split(context_lines_text, '\n')
      last_line_number = data.line_number + #context_lines - 1

      addResultLines(context_lines, {
        start = {
          line = data.line_number,
          column = nil,
        },
        ['end'] = {
          line = last_line_number,
          column = nil,
        },
      }, lines, highlights, change_sign)
    end
  end

  return {
    lines = lines,
    highlights = highlights,
    stats = stats,
  }
end

return M
