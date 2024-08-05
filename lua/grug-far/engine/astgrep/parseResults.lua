local utils = require('grug-far/utils')

---@type ResultHighlightSign
local removed_sign = { icon = 'resultsChangeIndicator', hl = 'GrugFarResultsRemoveIndicator' }
local added_sign = { icon = 'resultsChangeIndicator', hl = 'GrugFarResultsAddIndicator' }

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
        hl = 'GrugFarResultsPath',
        start_line = #lines,
        start_col = 1,
        end_line = #lines,
        end_col = #match.file,
      })
      table.insert(lines, match.file)
    end

    local numlines = #lines
    for j, matchLine in ipairs(vim.split(match.lines, '\n')) do
      local current_line = numlines + j - 1
      local isLastLine = j == match.range['end'].line - match.range.start.line + 1
      local line_no = tostring(match.range.start.line + j - 1)
      local col_no = j == 1 and tostring(match.range.start.column) or nil
      local prefix = col_no and line_no .. ':' .. col_no .. ':' or line_no .. '-'

      table.insert(highlights, {
        -- TODO (sbadragan): reference some enum
        hl = 'GrugFarResultsLineNo',
        start_line = current_line,
        start_col = 0,
        end_line = current_line,
        end_col = #line_no,
        sign = removed_sign,
      })
      if col_no then
        table.insert(highlights, {
          hl = 'GrugFarResultsLineColumn',
          start_line = current_line,
          start_col = #line_no + 1, -- skip ':'
          end_line = current_line,
          end_col = #line_no + 1 + #col_no,
        })
      end

      matchLine = prefix .. matchLine
      table.insert(highlights, {
        hl = 'GrugFarResultsMatch',
        start_line = current_line,
        start_col = j == 1 and #prefix + match.range.start.column or #prefix,
        end_line = current_line,
        end_col = isLastLine and #prefix + match.range['end'].column or #matchLine,
      })

      table.insert(lines, utils.getLineWithoutCarriageReturn(matchLine))
    end

    -- add replacements lines
    if match.replacement then
      local matchLinesStr = match.lines
      local matchStart = match.range.start.column + 1 -- column is zero-based
      local matchEnd = matchStart + #match.text - 1
      local replacedStr = matchLinesStr:sub(1, matchStart - 1)
        .. match.replacement
        .. matchLinesStr:sub(matchEnd + 1, -1)

      for _, replacementLine in ipairs(vim.split(replacedStr, '\n')) do
        table.insert(lines, utils.getLineWithoutCarriageReturn(replacementLine))
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
