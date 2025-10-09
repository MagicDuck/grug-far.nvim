local utils = require('grug-far.utils')
local engine = require('grug-far.engine')
local ResultHighlightType = engine.ResultHighlightType
local ResultMarkType = engine.ResultMarkType
local ResultSigns = engine.ResultSigns
local ResultHighlightByType = engine.ResultHighlightByType

local M = {}

---@class grug.far.AstgrepMatchPos
---@field line integer
---@field column integer

---@class grug.far.AstgrepMatchByteOffset
---@field start integer
---@field end integer

---@class grug.far.AstgrepMatchRange
---@field start grug.far.AstgrepMatchPos
---@field end grug.far.AstgrepMatchPos
---@field byteOffset grug.far.AstgrepMatchByteOffset

---@class grug.far.AstgrepMatchCharCount
---@field leading integer
---@field trailing integer

---@class grug.far.AstgrepMatch
---@field file string
---@field lines string
---@field text string
---@field replacement string
---@field range grug.far.AstgrepMatchRange
---@field charCount? grug.far.AstgrepMatchCharCount

--- adds result lines
---@param file_name string? associated file
---@param resultLines string[] lines to add
---@param range grug.far.AstgrepMatchRange
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
  range,
  lines,
  highlights,
  marks,
  sign,
  matchHighlightType,
  bufrange,
  mark_opts
)
  local numlines = #lines
  for j, resultLine in ipairs(resultLines) do
    local current_line = numlines + j - 1
    local isLastLine = j == #resultLines
    local lnum = bufrange and bufrange.start_row - 1 + range.start.line + j or range.start.line + j
    local column_number = range.start.column and range.start.column + 1 or nil
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
      table.insert(highlights, {
        hl_group = ResultHighlightByType[matchHighlightType],
        start_line = current_line,
        start_col = j == 1 and range.start.column or 0,
        end_line = current_line,
        end_col = isLastLine and range['end'].column or #resultLine,
      })
    end

    table.insert(lines, resultLine)
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
---@param matches grug.far.AstgrepMatch[]
---@param bufrange grug.far.VisualSelectionInfo?
---@param isFirst boolean
---@return grug.far.ParsedResultsData
function M.parseResults(matches, bufrange, isFirst)
  ---@type grug.far.ParsedResultsStats
  local stats = { files = 0, matches = 0 }
  ---@type string[]
  local lines = {}
  ---@type grug.far.ResultHighlight[]
  local highlights = {}
  ---@type grug.far.ResultMark[]
  local marks = {}

  local is_first_one = isFirst
  local file_name = nil
  for i = 1, #matches, 1 do
    local match = matches[i]
    stats.matches = stats.matches + 1
    local isFileBoundary = i == 1 or match.file ~= matches[i - 1].file

    if isFileBoundary and not is_first_one then
      table.insert(lines, '')
    end
    is_first_one = false

    if isFileBoundary then
      stats.files = stats.files + 1
      file_name = bufrange and bufrange.file_name or vim.fs.normalize(match.file)
      table.insert(highlights, {
        hl_group = ResultHighlightByType[ResultHighlightType.FilePath],
        start_line = #lines,
        start_col = 0,
        end_line = #lines,
        end_col = #file_name,
      })
      table.insert(lines, file_name)
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
      addResultLines(
        file_name,
        leadingLines,
        leadingRange,
        lines,
        highlights,
        marks,
        match.replacement and ResultSigns.Changed or nil,
        nil,
        bufrange,
        { is_context = true }
      )
    end

    -- add match lines
    local lineNumberSign = match.replacement and ResultSigns.Removed or nil
    local matchHighlightType = match.replacement and ResultHighlightType.MatchRemoved
      or ResultHighlightType.Match
    local matchLines = vim.split(matchLinesStr, '\n')
    local next_mark_index = #marks + 1
    addResultLines(
      file_name,
      matchLines,
      match.range,
      lines,
      highlights,
      marks,
      lineNumberSign,
      matchHighlightType,
      bufrange
    )
    marks[next_mark_index].location.is_counted = true

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
        file_name,
        replacedLines,
        replaceRange,
        lines,
        highlights,
        marks,
        ResultSigns.Added,
        ResultHighlightType.MatchAdded,
        bufrange
      )
    end

    -- add trailing lines
    if #trailingLinesStr > 0 then
      local trailingLines = vim.split(trailingLinesStr, '\n')
      local trailingRange = vim.deepcopy(match.range)
      trailingRange.start.column = nil
      trailingRange.start.line = match.range['end'].line + 1
      addResultLines(
        file_name,
        trailingLines,
        trailingRange,
        lines,
        highlights,
        marks,
        match.replacement and ResultSigns.Changed or nil,
        nil,
        bufrange,
        { is_context = true }
      )
    end

    -- add separator
    if
      (match.replacement or #leadingLinesStr > 0 or #trailingLinesStr > 0)
      and i ~= #matches
      and match.file == matches[i + 1].file
    then
      table.insert(marks, {
        type = ResultMarkType.DiffSeparator,
        start_line = #lines,
        start_col = 0,
        end_line = #lines,
        end_col = 0,
        sign = match.replacement and ResultSigns.DiffSeparator or nil,
        location = {
          filename = file_name,
        },
      })
      table.insert(lines, engine.DiffSeparatorChars)
    end
  end

  return {
    lines = lines,
    highlights = highlights,
    marks = marks,
    stats = stats,
  }
end

--- decodes streamed json matches, appending to given table
---@param matches grug.far.AstgrepMatch[]
---@param data string
---@param eval_fn? fun(...): (string?, string?)
---@return string? err
function M.json_decode_matches(matches, data, eval_fn)
  local firstEvalErr = nil
  local json_lines = vim.split(data, '\n')
  for _, json_line in ipairs(json_lines) do
    if #json_line > 0 then
      local success, match = pcall(vim.json.decode, json_line)
      if not success then
        return '__json_decode_error__'
      end
      if eval_fn then
        local vars = {}
        if match.metaVariables then
          for name, value in pairs(match.metaVariables.single) do
            vars[name] = value.text
          end
          for name, value in pairs(match.metaVariables.multi) do
            vars[name] = vim
              .iter(value)
              :map(function(v)
                return v.text
              end)
              :totable()
          end
        end
        local replacementText, err = eval_fn(match.text, vars)
        if err then
          firstEvalErr = firstEvalErr or err
          replacementText = ''
        end
        match.replacement = replacementText
      end
      table.insert(matches, match)
    end
  end

  return firstEvalErr
end

--- splits off matches corresponding to the last file
---@param matches grug.far.AstgrepMatch[]
---@return grug.far.AstgrepMatch[] before, grug.far.AstgrepMatch[] after
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
---@param matches grug.far.AstgrepMatch[]
---@return grug.far.AstgrepMatch[][] matches_per_file
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
---@param matches grug.far.AstgrepMatch[]
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
