local utils = require('grug-far.utils')
local engine = require('grug-far.engine')
local ResultHighlightType = engine.ResultHighlightType
local ResultMarkType = engine.ResultMarkType
local ResultSigns = engine.ResultSigns
local ResultHighlightByType = engine.ResultHighlightByType

local M = {}

---@class grug.far.RipgrepJsonSubmatch
---@field match {text: string}
---@field replacement {text: string}
---@field start integer
---@field end integer

---@class grug.far.RipgrepJsonMatchData
---@field lines { text: string}
---@field line_number integer
---@field absolute_offset integer
---@field submatches grug.far.RipgrepJsonSubmatch[]

---@class grug.far.RipgrepJsonMatch
---@field type "match"
---@field data grug.far.RipgrepJsonMatchData

---@class grug.far.RipgrepJsonMatchContext
---@field type "context"
---@field data grug.far.RipgrepJsonMatchData

---@class grug.far.RipgrepJsonMatchBegin
---@field type "begin"
---@field data { path: { text: string } }

---@class grug.far.RipgrepJsonMatchEnd
---@field type "end"
---@field data { path: { text: string } }
-- note: this one has more stats things, but we don't care about them, atm.

---@class grug.far.RipgrepJsonMatchSummary
---@field type "summary"
-- note: this one has more stats things, but we don't care about them, atm.

---@alias RipgrepJson grug.far.RipgrepJsonMatchSummary | grug.far.RipgrepJsonMatchBegin | grug.far.RipgrepJsonMatchEnd | grug.far.RipgrepJsonMatch | grug.far.RipgrepJsonMatchContext

--- adds result lines
---@param file_name string? associated file
---@param resultLines string[] lines to add
---@param ranges { start: { column: integer?, line: integer}, end: {column: integer?, line: integer}}[]
---@param lines string[] lines table to add to
---@param highlights grug.far.ResultHighlight[] highlights table to add to
---@param marks grug.far.ResultMark[] marks to add to
---@param sign? grug.far.ResultHighlightSign
---@param matchHighlightType? ResultHighlightType
---@param bufrange? grug.far.VisualSelectionInfo
---@param mark_opts? any
local function addResultLines(
  file_name,
  resultLines,
  ranges,
  lines,
  highlights,
  marks,
  sign,
  matchHighlightType,
  bufrange,
  mark_opts
)
  local numlines = #lines
  local first_range = ranges[1]
  for j, resultLine in ipairs(resultLines) do
    local current_line = numlines + j - 1
    local current_line_number = first_range.start.line + j - 1
    local lnum = bufrange and current_line_number + bufrange.start_row - 1 or current_line_number
    local column_number = first_range.start.column
    if bufrange and bufrange.start_col and column_number then
      column_number = column_number + bufrange.start_col
      bufrange.start_col = nil -- we only want to add col to first line
    end
    resultLine = utils.getLineWithoutCarriageReturn(resultLine)

    local mark = {
      type = ResultMarkType.SourceLocation,
      start_line = current_line,
      start_col = 0,
      end_line = current_line,
      end_col = #resultLine,
      location = {
        filename = file_name,
        lnum = lnum,
        col = column_number,
        text = resultLine,
      },
      sign = sign,
    }
    if mark_opts then
      for key, value in pairs(mark_opts) do
        mark[key] = value
      end
    end
    table.insert(marks, mark)

    if matchHighlightType then
      for _, range in ipairs(ranges) do
        if range.start.line <= current_line_number and range['end'].line >= current_line_number then
          table.insert(highlights, {
            hl_group = ResultHighlightByType[matchHighlightType],
            start_line = current_line,
            start_col = range.start.line == current_line_number and range.start.column - 1 or 0,
            end_line = current_line,
            end_col = range['end'].line == current_line_number and range['end'].column - 1
              or #resultLine,
          })
        end
      end
    end

    table.insert(lines, resultLine)
  end
end

--- parse results data and get info
---@param matches RipgrepJson[]
---@param isSearchWithReplace boolean
---@param showDiff boolean
---@param bufrange? grug.far.VisualSelectionInfo
---@param isFirst? boolean
---@return grug.far.ParsedResultsData
function M.parseResults(matches, isSearchWithReplace, showDiff, bufrange, isFirst)
  ---@type grug.far.ParsedResultsStats
  local stats = { files = 0, matches = 0 }
  ---@type string[]
  local lines = {}
  ---@type grug.far.ResultHighlight[]
  local highlights = {}
  ---@type grug.far.ResultMark[]
  local marks = {}

  local is_first_one = isFirst
  local last_line_number = nil
  local file_name = nil
  local last_context_line_number = nil
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
      table.insert(marks, {
        type = ResultMarkType.DiffSeparator,
        start_line = #lines,
        start_col = 0,
        end_line = #lines,
        end_col = 0,
        sign = isSearchWithReplace and ResultSigns.DiffSeparator or nil,
        location = {
          filename = file_name,
        },
      })
      table.insert(lines, engine.DiffSeparatorChars)
      last_line_number = nil
    end

    if match.type == 'begin' then
      if not is_first_one then
        table.insert(lines, '')
      end
      is_first_one = false

      stats.files = stats.files + 1
      last_context_line_number = nil
      file_name = bufrange and bufrange.file_name or vim.fs.normalize(data.path.text)
      table.insert(highlights, {
        hl_group = ResultHighlightByType[ResultHighlightType.FilePath],
        start_line = #lines,
        start_col = 0,
        end_line = #lines,
        end_col = #file_name,
      })
      table.insert(marks, {
        type = ResultMarkType.SourceLocation,
        start_line = #lines,
        start_col = 0,
        end_line = #lines,
        end_col = #file_name,
        location = {
          filename = file_name,
        },
      })
      table.insert(lines, file_name)
    elseif match.type == 'end' then
      last_line_number = nil
    elseif match.type == 'match' then
      last_context_line_number = nil
      stats.matches = stats.matches + #data.submatches
      local match_lines_text = utils.strip_trailing_newline(data.lines.text or '')
      local match_lines = vim.split(match_lines_text, '\n')
      last_line_number = data.line_number + #match_lines - 1

      -- add match lines
      if not isSearchWithReplace or (isSearchWithReplace and showDiff) then
        local sign = (isSearchWithReplace and showDiff) and ResultSigns.Removed or nil
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

        local next_mark_index = #marks + 1
        addResultLines(
          file_name,
          match_lines,
          ranges,
          lines,
          highlights,
          marks,
          sign,
          matchHighlightType,
          bufrange
        )
        marks[next_mark_index].location.is_counted = true
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
        local sign = showDiff and ResultSigns.Added or ResultSigns.Changed
        local matchHighlightType = showDiff and ResultHighlightType.MatchAdded
          or ResultHighlightType.Match

        addResultLines(
          file_name,
          replaced_lines,
          ranges,
          lines,
          highlights,
          marks,
          sign,
          matchHighlightType,
          bufrange
        )
      end
    elseif match.type == 'context' then
      if
        not isSearchWithReplace
        and last_context_line_number
        and last_context_line_number + 1 < match.data.line_number
      then
        table.insert(marks, {
          type = ResultMarkType.DiffSeparator,
          start_line = #lines,
          start_col = 0,
          end_line = #lines,
          end_col = 0,
          location = {
            filename = file_name,
          },
        })
        table.insert(lines, engine.DiffSeparatorChars)
      end
      last_context_line_number = match.data.line_number
      local context_lines_text = utils.strip_trailing_newline(data.lines.text or '')
      local context_lines = vim.split(context_lines_text, '\n')
      last_line_number = data.line_number + #context_lines - 1

      local ranges = {
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
      }
      addResultLines(
        file_name,
        context_lines,
        ranges,
        lines,
        highlights,
        marks,
        isSearchWithReplace and ResultSigns.Changed or nil,
        nil,
        bufrange,
        { is_context = true }
      )
    end
  end

  return {
    lines = lines,
    highlights = highlights,
    marks = marks,
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

--- splits off matches corresponding to the last file
---@param matches RipgrepJson[]
---@return RipgrepJson[] before, RipgrepJson[] after
function M.split_last_file_matches(matches)
  local end_index = 0
  for i = #matches, 1, -1 do
    if matches[i].type == 'end' then
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

return M
