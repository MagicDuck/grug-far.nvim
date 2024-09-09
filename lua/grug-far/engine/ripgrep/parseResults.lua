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
---@param ranges { start: { column: integer?, line: integer}, end: {column: integer?, line: integer}}[]
---@param lines string[] lines table to add to
---@param highlights ResultHighlight[] highlights table to add to
---@param lineNumberSign? ResultHighlightSign
---@param matchHighlightType? ResultHighlightType
local function addResultLines(
  resultLines,
  ranges,
  lines,
  highlights,
  lineNumberSign,
  matchHighlightType
)
  local numlines = #lines
  local first_range = ranges[1]
  for j, resultLine in ipairs(resultLines) do
    local current_line = numlines + j - 1
    local current_line_number = first_range.start.line + j - 1
    local line_no = tostring(current_line_number)
    local col_no = first_range.start.column and tostring(first_range.start.column) or nil
    local prefix = line_no .. (col_no and ':' .. col_no .. ':' or '-')

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
      for _, range in ipairs(ranges) do
        if range.start.line <= current_line_number and range['end'].line >= current_line_number then
          table.insert(highlights, {
            hl_type = matchHighlightType,
            hl = HighlightByType[matchHighlightType],
            start_line = current_line,
            start_col = range.start.line == current_line_number
                and #prefix + range.start.column - 1
              or #prefix,
            end_line = current_line,
            end_col = range['end'].line == current_line_number
                and #prefix + range['end'].column - 1
              or #resultLine,
          })
        end
      end
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
      local match_lines_text = data.lines.text:sub(1, -2) -- strip trailing newline
      local match_lines = vim.split(match_lines_text, '\n')
      last_line_number = data.line_number + #match_lines - 1

      -- add match lines
      if not isSearchWithReplace or (isSearchWithReplace and showDiff) then
        local lineNumberSign = (isSearchWithReplace and showDiff) and removed_sign or nil
        local matchHighlightType = (isSearchWithReplace and showDiff)
            and ResultHighlightType.MatchRemoved
          or ResultHighlightType.Match
        local ranges = vim
          .iter(data.submatches)
          :map(function(submatch)
            local text_to_submatch = match_lines_text:sub(1, submatch.start)
            local start_line = data.line_number + vim.fn.count(text_to_submatch, '\n')
            return {
              start = {
                line = start_line,
                column = submatch.start - (utils.strFindLast(text_to_submatch, '\n') or 0) + 1,
              },
              ['end'] = {
                line = start_line + vim.fn.count(submatch.match.text, '\n'),
                column = submatch['end']
                  - (utils.strFindLast(text_to_submatch .. submatch.match.text, '\n') or 0)
                  + 1,
              },
            }
          end)
          :totable()

        addResultLines(match_lines, ranges, lines, highlights, lineNumberSign, matchHighlightType)
      end

      -- add replacement lines
      if isSearchWithReplace then
        -- build lines text with replacements spliced in for matches and figure out match ranges
        local last_index = 0
        local replaced_lines_text = ''
        local ranges = {}
        for _, submatch in ipairs(data.submatches) do
          replaced_lines_text = replaced_lines_text
            .. match_lines_text:sub(last_index + 1, submatch.start)

          local start_line = data.line_number + vim.fn.count(replaced_lines_text, '\n')
          table.insert(ranges, {
            start = {
              line = start_line,
              column = #replaced_lines_text
                - (utils.strFindLast(replaced_lines_text, '\n') or 0)
                + 1,
            },
            ['end'] = {
              line = start_line + vim.fn.count(submatch.replacement.text, '\n'),
              column = #replaced_lines_text + #submatch.replacement.text - (utils.strFindLast(
                replaced_lines_text .. submatch.replacement.text,
                '\n'
              ) or 0) + 1,
            },
          })

          replaced_lines_text = replaced_lines_text .. submatch.replacement.text
          last_index = submatch['end']
        end
        if last_index < #match_lines_text then
          replaced_lines_text = replaced_lines_text .. match_lines_text:sub(last_index + 1)
        end

        local replaced_lines = vim.split(replaced_lines_text, '\n')

        addResultLines(
          replaced_lines,
          ranges,
          lines,
          highlights,
          added_sign,
          ResultHighlightType.MatchAdded
        )
      end
    elseif match.type == 'context' then
      local context_lines_text = data.lines.text:sub(1, -2) -- strip trailing newline
      local context_lines = vim.split(context_lines_text, '\n')
      last_line_number = data.line_number + #context_lines - 1

      addResultLines(context_lines, {
        {
          start = {
            line = data.line_number,
            column = nil,
          },
          ['end'] = {
            line = last_line_number,
            column = nil,
          },
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
