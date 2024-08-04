local utils = require('grug-far/utils')

--- parse results data and get info
---@param data string
---@return ParsedResultsData
local function parseResults(data)
  -- TODO (sbadragan): parse the json=stream data and return it.
  -- return { lines = vim.split(data, '\n'), highlights = {}, stats = { files = 1, matches = 1 } }

  local json_lines = vim.split(data, '\n')
  local lines = {}
  local lastRange
  for _, json_line in ipairs(json_lines) do
    if #json_line > 0 then
      -- TODO (sbadragan): add a type on this thing
      local match = vim.json.decode(json_line)
      local matchLines = vim.split(match.lines, '\n')
      if lastRange then
        -- remove duplicated lines
        for i = 1, lastRange['end'].line - match.range.start.line + 1, 1 do
          -- use overlapping lines from last match that have replacement performed
          -- as first lines of this match so that we get stacked replacements
          -- TODO (sbadragan): but if we do this, the replacement will be become wrong...
          local lastLine = table.remove(lines, #lines)
          table.remove(matchLines, i)
          table.insert(matchLines, 1, lastLine)
        end
      end

      -- perform replacements
      if match.replacement then
      end

      -- add new lines
      local newlines = vim.split(matchLines, '\n')
      for _, newline in ipairs(newlines) do
        table.insert(lines, utils.getLineWithoutCarriageReturn(newline))
      end

      lastRange = match.range
    end
  end

  -- TODO (sbadragan): fixup
  return { lines = lines, highlights = {}, stats = { files = 1, matches = 1 } }
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
