local utils = require('grug-far.utils')
local engine = require('grug-far.engine')
local ResultHighlightType = engine.ResultHighlightType
local ResultLineGroup = engine.ResultLineGroup

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
  [ResultHighlightType.NumbersSeparator] = 'GrugFarResultsNumbersSeparator',
  [ResultHighlightType.LinePrefixEdge] = 'GrugFarResultsLinePrefixEdge',
  [ResultHighlightType.FilePath] = 'GrugFarResultsPath',
  [ResultHighlightType.Match] = 'GrugFarResultsMatch',
  [ResultHighlightType.MatchAdded] = 'GrugFarResultsMatchAdded',
  [ResultHighlightType.MatchRemoved] = 'GrugFarResultsMatchRemoved',
  [ResultHighlightType.DiffSeparator] = 'Normal',
}

local last_line_group_id = 0
local function get_next_line_group_id()
  last_line_group_id = last_line_group_id + 1
  return last_line_group_id
end

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
---@param line_group ResultLineGroup
---@param lineNumberSign? ResultHighlightSign
---@param matchHighlightType? ResultHighlightType
---@param bufrange? VisualSelectionInfo
local function addResultLines(
  resultLines,
  ranges,
  lines,
  highlights,
  line_group,
  lineNumberSign,
  matchHighlightType,
  bufrange
)
  local line_group_id = get_next_line_group_id()
  local numlines = #lines
  local first_range = ranges[1]
  for j, resultLine in ipairs(resultLines) do
    local current_line = numlines + j - 1
    local current_line_number = first_range.start.line + j - 1
    local line_no = ' '
      .. tostring(bufrange and current_line_number + bufrange.start_row - 1 or current_line_number)
    local column_number = first_range.start.column
    if bufrange and bufrange.start_col and column_number then
      column_number = column_number + bufrange.start_col
      bufrange.start_col = nil -- we only want to add col to first line
    end
    local col_no = column_number and tostring(column_number) .. ' ' or ' '

    local num_sep = col_no and ':' or ' '
    -- TODO (sbadragan): use configurable char here at end?
    -- local edge_symbol = '│'
    -- local edge_symbol = '┇'
    -- local edge_symbol = '║'
    -- local edge_symbol = '⦚'
    -- local edge_symbol = '┊'
    -- local edge_symbol = '│'
    local edge_symbol = ' '
    local line_no_len = #line_no
    local col_no_len = #col_no
    local line_prefix_len = line_no_len + #num_sep + col_no_len + #edge_symbol

    table.insert(highlights, {
      line_group = line_group,
      line_group_id = line_group_id,
      hl_type = ResultHighlightType.LineNumber,
      hl = HighlightByType[ResultHighlightType.LineNumber],
      start_line = current_line,
      start_col = 0,
      end_line = current_line,
      end_col = #line_no,
      sign = lineNumberSign,
      line_no_len = line_no_len,
      col_no_len = col_no_len,
    })
    if column_number then
      table.insert(highlights, {
        line_group = line_group,
        line_group_id = line_group_id,
        hl_type = ResultHighlightType.NumbersSeparator,
        hl = HighlightByType[ResultHighlightType.NumbersSeparator],
        start_line = current_line,
        start_col = #line_no,
        end_line = current_line,
        end_col = #line_no + 1,
        line_no_len = line_no_len,
        col_no_len = col_no_len,
      })
      table.insert(highlights, {
        line_group = line_group,
        line_group_id = line_group_id,
        hl_type = ResultHighlightType.ColumnNumber,
        hl = HighlightByType[ResultHighlightType.ColumnNumber],
        start_line = current_line,
        start_col = #line_no + 1,
        end_line = current_line,
        end_col = #line_no + 1 + #col_no,
        line_no_len = line_no_len,
        col_no_len = col_no_len,
      })
    end
    if #edge_symbol > 0 then
      table.insert(highlights, {
        line_group = line_group,
        line_group_id = line_group_id,
        hl_type = ResultHighlightType.LinePrefixEdge,
        hl = HighlightByType[ResultHighlightType.LinePrefixEdge],
        start_line = current_line,
        start_col = #line_no + 1 + #col_no,
        end_line = current_line,
        end_col = #line_no + 1 + #col_no + #edge_symbol,
        line_no_len = line_no_len,
        col_no_len = col_no_len,
      })
    end

    resultLine = resultLine
    if matchHighlightType then
      for _, range in ipairs(ranges) do
        if range.start.line <= current_line_number and range['end'].line >= current_line_number then
          table.insert(highlights, {
            line_group = line_group,
            line_group_id = line_group_id,
            hl_type = matchHighlightType,
            hl = HighlightByType[matchHighlightType],
            start_line = current_line,
            start_col = range.start.line == current_line_number
                and line_prefix_len + range.start.column - 1
              or line_prefix_len,
            end_line = current_line,
            end_col = range['end'].line == current_line_number
                and line_prefix_len + range['end'].column - 1
              or (line_prefix_len + #resultLine),
            line_no_len = line_no_len,
            col_no_len = col_no_len,
          })
        end
      end
    end

    table.insert(lines, {
      line_no = line_no,
      num_sep = num_sep,
      col_no = col_no,
      edge_symbol = edge_symbol,
      line = utils.getLineWithoutCarriageReturn(resultLine),
    })
  end
end

-- TODO (sbadragan): could be reusable function across parsers
local function align_prefixes(lines, line_range, highlights, hl_range)
  -- fix line:col alignment
  -- TODO (sbadragan): have configurable min values for those?
  local max_line_no_len = 0 -- 4
  local max_col_no_len = 0 -- 4
  for i = hl_range[1], hl_range[2], 1 do
    local highlight = highlights[i]
    if highlight.hl_type == ResultHighlightType.LineNumber then
      local len = highlight.end_col - highlight.start_col
      if len > max_line_no_len then
        max_line_no_len = len
      end
    end
    if highlight.hl_type == ResultHighlightType.ColumnNumber then
      local len = highlight.end_col - highlight.start_col
      if len > max_col_no_len then
        max_col_no_len = len
      end
    end
  end

  -- shift highlights
  for i = hl_range[1], hl_range[2], 1 do
    local highlight = highlights[i]
    if
      highlight.line_no_len
      and not (highlight.line_no_len == max_line_no_len and highlight.col_no_len == max_col_no_len)
    then
      local col_no_diff = max_col_no_len - highlight.col_no_len
      local line_no_diff = max_line_no_len - highlight.line_no_len
      if highlight.hl_type == ResultHighlightType.LineNumber then
        highlight.start_col = 0
        highlight.end_col = highlight.end_col + line_no_diff
      elseif highlight.hl_type == ResultHighlightType.NumbersSeparator then
        highlight.start_col = highlight.start_col + line_no_diff
        highlight.end_col = highlight.end_col + line_no_diff
      elseif highlight.hl_type == ResultHighlightType.ColumnNumber then
        highlight.start_col = highlight.start_col + line_no_diff
        highlight.end_col = highlight.end_col + line_no_diff + col_no_diff
      else
        highlight.start_col = highlight.start_col + line_no_diff + col_no_diff
        highlight.end_col = highlight.end_col + line_no_diff + col_no_diff
      end
      highlight.line_no_len = nil
      highlight.col_no_len = nil
    end
  end

  for i = line_range[1], line_range[2], 1 do
    local line = lines[i]
    if type(line) == 'table' then
      lines[i] = ('%' .. max_line_no_len .. 's'):format(line.line_no)
        .. line.num_sep
        .. ('%-' .. max_col_no_len .. 's'):format(line.col_no)
        .. line.edge_symbol
        .. line.line
    end
  end
end

--- parse results data and get info
---@param matches RipgrepJson[]
---@param isSearchWithReplace boolean
---@param showDiff boolean
---@param bufrange? VisualSelectionInfo
---@return ParsedResultsData
-- TODO (sbadragan): need to make sure all the matches for one file are passed in together, as the maxima are calculated per-file
function M.parseResults(matches, isSearchWithReplace, showDiff, bufrange)
  local stats = { files = 0, matches = 0 }
  local lines = {}
  local highlights = {}
  local last_aligned_line = 0
  local last_aligned_highlight = 0

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
        line_group = ResultLineGroup.DiffSeparator,
        line_group_id = get_next_line_group_id(),
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
      local file_name = bufrange and bufrange.file_name or data.path.text
      table.insert(highlights, {
        line_group = ResultLineGroup.FilePath,
        line_group_id = get_next_line_group_id(),
        hl_type = ResultHighlightType.FilePath,
        hl = HighlightByType[ResultHighlightType.FilePath],
        start_line = #lines,
        start_col = 0,
        end_line = #lines,
        end_col = #file_name,
      })
      table.insert(lines, file_name)
    elseif match.type == 'end' then
      last_line_number = nil
      table.insert(lines, '')
      align_prefixes(
        lines,
        { last_aligned_line + 1, #lines },
        highlights,
        { last_aligned_highlight + 1, #highlights }
      )
      last_aligned_line = #lines
      last_aligned_highlight = #highlights
    elseif match.type == 'match' then
      stats.matches = stats.matches + #data.submatches
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

        addResultLines(
          match_lines,
          ranges,
          lines,
          highlights,
          ResultLineGroup.MatchLines,
          lineNumberSign,
          matchHighlightType,
          bufrange
        )
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
        local lineNumberSign = showDiff and added_sign or change_sign
        local matchHighlightType = showDiff and ResultHighlightType.MatchAdded
          or ResultHighlightType.Match

        addResultLines(
          replaced_lines,
          ranges,
          lines,
          highlights,
          ResultLineGroup.ReplacementLines,
          lineNumberSign,
          matchHighlightType,
          bufrange
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
      }, lines, highlights, ResultLineGroup.ContextLines, change_sign, nil, bufrange)
    end
  end

  align_prefixes(
    lines,
    { last_aligned_line + 1, #lines },
    highlights,
    { last_aligned_highlight + 1, #highlights }
  )

  return {
    lines = lines,
    highlights = highlights,
    stats = stats,
  }
end

--- constructs new file content, given old file content and matches with replacements
---@param contents string
---@param matches RipgrepJson[]
---@return string new_contents
function M.getReplacedContents(contents, matches)
  local new_contents = ''
  local last_index = 0
  for _, match in ipairs(matches) do
    if match.type == 'match' then
      new_contents = new_contents .. contents:sub(last_index + 1, match.data.absolute_offset)

      local last_sub_index = 0
      local replaced_lines_text = ''
      local match_lines_text = match.data.lines.text
      for _, submatch in ipairs(match.data.submatches) do
        replaced_lines_text = replaced_lines_text
          .. match_lines_text:sub(last_sub_index + 1, submatch.start)
          .. submatch.replacement.text
        last_sub_index = submatch['end']
      end
      if last_sub_index < #match_lines_text then
        replaced_lines_text = replaced_lines_text .. match_lines_text:sub(last_sub_index + 1)
      end
      new_contents = new_contents .. replaced_lines_text

      last_index = match.data.absolute_offset + #match_lines_text
    end
  end
  if last_index < #contents then
    new_contents = new_contents .. contents:sub(last_index + 1)
  end

  return new_contents
end

return M
