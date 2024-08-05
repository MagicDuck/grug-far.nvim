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

-- TODO (sbadragan): add types
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
    local col_no = j == 1 and tostring(range.start.column) or nil
    local prefix = col_no and line_no .. ':' .. col_no .. ':' or line_no .. '-'

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
        start_col = 1,
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

-- Sample output:
-- console.log($A, $B, $C, $D, $E) on multi line
-- {
--   "text": "console.log(\n        'Error occurred when reading',\n        filePath,\n        filePath,\n        filePath,\n        filePath,\n      )",
--   "range": {
--     "byteOffset": {
--       "start": 1062,
--       "end": 1193
--     },
--     "start": {
--       "line": 24,
--       "column": 6
--     },
--     "end": {
--       "line": 30,
--       "column": 7
--     }
--   },
--   "file": "/opt/repos/frontend/scripts/update-tsconfig.mjs",
--   "lines": "      console.log(\n        'Error occurred when reading',\n        filePath,\n        filePath,\n        filePath,\n        filePath,\n      );",
--   "replacement": "boborepl.log('Error occurred when reading', filePath, filePath, filePath, filePath)",
--   "replacementOffsets": {
--     "start": 1062,
--     "end": 1193
--   },
--   "language": "JavaScript",
--   "metaVariables": {
--     "single": {
--       "E": {
--         "text": "filePath",
--         "range": {
--           "byteOffset": {
--             "start": 1176,
--             "end": 1184
--           },
--           "start": {
--             "line": 29,
--             "column": 8
--           },
--           "end": {
--             "line": 29,
--             "column": 16
--           }
--         }
--       },
--       "C": {
--         "text": "filePath",
--         "range": {
--           "byteOffset": {
--             "start": 1140,
--             "end": 1148
--           },
--           "start": {
--             "line": 27,
--             "column": 8
--           },
--           "end": {
--             "line": 27,
--             "column": 16
--           }
--         }
--       },
--       "A": {
--         "text": "'Error occurred when reading'",
--         "range": {
--           "byteOffset": {
--             "start": 1083,
--             "end": 1112
--           },
--           "start": {
--             "line": 25,
--             "column": 8
--           },
--           "end": {
--             "line": 25,
--             "column": 37
--           }
--         }
--       },
--       "D": {
--         "text": "filePath",
--         "range": {
--           "byteOffset": {
--             "start": 1158,
--             "end": 1166
--           },
--           "start": {
--             "line": 28,
--             "column": 8
--           },
--           "end": {
--             "line": 28,
--             "column": 16
--           }
--         }
--       },
--       "B": {
--         "text": "filePath",
--         "range": {
--           "byteOffset": {
--             "start": 1122,
--             "end": 1130
--           },
--           "start": {
--             "line": 26,
--             "column": 8
--           },
--           "end": {
--             "line": 26,
--             "column": 16
--           }
--         }
--       }
--     },
--     "multi": {},
--     "transformed": {}
--   }
-- }

-- multiple things on the same line:
-- const refs = nodes.map(node => ({
--   path: path.relative(refNode ? refNode.dir : rootDir, node.dir),
-- }));
-- search for:
-- $A.dir
-- bob
--
--
-- /opt/repos/frontend/scripts/update-tsconfig.mjs
-- {
--   "text": "refNode.dir",
--   "range": {
--     "byteOffset": {
--       "start": 1623,
--       "end": 1634
--     },
--     "start": {
--       "line": 50,
--       "column": 34
--     },
--     "end": {
--       "line": 50,
--       "column": 45
--     }
--   },
--   "file": "/opt/repos/frontend/scripts/update-tsconfig.mjs",
--   "lines": "    path: path.relative(refNode ? refNode.dir : rootDir, node.dir),",
--   "replacement": "bob",
--   "replacementOffsets": {
--     "start": 1623,
--     "end": 1634
--   },
--   "language": "JavaScript",
--   "metaVariables": {
--     "single": {
--       "A": {
--         "text": "refNode",
--         "range": {
--           "byteOffset": {
--             "start": 1623,
--             "end": 1630
--           },
--           "start": {
--             "line": 50,
--             "column": 34
--           },
--           "end": {
--             "line": 50,
--             "column": 41
--           }
--         }
--       }
--     },
--     "multi": {},
--     "transformed": {}
--   }
-- }
-- next one
-- {
--   "text": "node.dir",
--   "range": {
--     "byteOffset": {
--       "start": 1646,
--       "end": 1654
--     },
--     "start": {
--       "line": 50,
--       "column": 57
--     },
--     "end": {
--       "line": 50,
--       "column": 65
--     }
--   },
--   "file": "/opt/repos/frontend/scripts/update-tsconfig.mjs",
--   "lines": "    path: path.relative(refNode ? refNode.dir : rootDir, node.dir),",
--   "replacement": "bob",
--   "replacementOffsets": {
--     "start": 1646,
--     "end": 1654
--   },
--   "language": "JavaScript",
--   "metaVariables": {
--     "single": {
--       "A": {
--         "text": "node",
--         "range": {
--           "byteOffset": {
--             "start": 1646,
--             "end": 1650
--           },
--           "start": {
--             "line": 50,
--             "column": 57
--           },
--           "end": {
--             "line": 50,
--             "column": 61
--           }
--         }
--       }
--     },
--     "multi": {},
--     "transformed": {}
--   }
-- }
