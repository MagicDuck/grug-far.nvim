--- parse results chunk and get info
---@param data string
---@return ParsedResultsData
local function parseResults(data)
  -- TODO (sbadragan): parse the json=stream data and return it.
  return { lines = vim.split(data, '\n'), highlights = {}, stats = { files = 1, matches = 1 } }
end

return parseResults

-- Sample output:
-- sg
-- console.log($M)
-- bobo($M)
-- --json=pretty

-- [
-- {
--   "text": "console.log('Linting...')",
--   "range": {
--     "byteOffset": {
--
--       "start": 1716,
--       "end": 1741
--     },
--     "start": {
--       "line": 63,
--       "column": 2
--     },
--     "end": {
--       "line": 63,
--       "column": 27
--     }
--   },
--   "file": "scripts/parallel-eslint.mjs",
--   "lines": "  console.log('Linting...');",
--   "replacement": "bobo('Linting...')",
--   "replacementOffsets": {
--     "start": 1716,
--     "end": 1741
--   },
--   "language": "JavaScript",
--   "metaVariables": {
--     "single": {
--       "M": {
--         "text": "'Linting...'",
--         "range": {
--           "byteOffset": {
--             "start": 1728,
--             "end": 1740
--           },
--           "start": {
--             "line": 63,
--             "column": 14
--           },
--           "end": {
--             "line": 63,
--             "column": 26
--           }
--         }
--       }
--     },
--     "multi": {},
--     "transformed": {}
--   }
-- },
