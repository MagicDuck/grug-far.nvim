local colors = require('grug-far/engine/ripgrep/colors')
local utils = require('grug-far/utils')
local ResultHighlightType = require('grug-far/engine').ResultHighlightType

--- @enum ResultsTokenType
local token_types = {
  color = 1,
  color_ending = 2,
  newline = 3,
}

---@type ResultHighlightSign
local change_sign = { icon = 'resultsChangeIndicator', hl = 'GrugFarResultsChangeIndicator' }

---@class ResultsToken
---@field type ResultsTokenType
---@field hl string
---@field hl_type ResultHighlightType
---@field name string
---@field start integer
---@field fin integer
---@field sign? ResultHighlightSign

--- gets tokens (line number, column, etc.) in results
---@param data string
---@param isSearchWithReplacement boolean
---@return ResultsToken[]
local function getTokens(data, isSearchWithReplacement)
  local tokens = {}
  local i
  local j

  for name, color in pairs(colors.rg_colors) do
    i = 0
    while true do
      i, j = string.find(data, color.ansi, i + 1, true)
      if i == nil then
        break
      end
      local token = {
        type = token_types.color,
        hl = color.hl,
        hl_type = color.hl_type,
        name = name,
        start = i,
        fin = j,
      }
      if isSearchWithReplacement and color.hl_type == ResultHighlightType.LineNumber then
        token.sign = change_sign
      end
      table.insert(tokens, token)
    end
  end

  i = 0
  while true do
    i, j = string.find(data, colors.ansi_color_ending, i + 1, true)
    if i == nil then
      break
    end
    table.insert(tokens, { type = token_types.color_ending, start = i, fin = j })
  end

  i = 0
  while true do
    i, j = string.find(data, '\n', i + 1, true)
    if i == nil then
      break
    end
    table.insert(tokens, { type = token_types.newline, start = i, fin = j })
  end

  table.sort(tokens, function(a, b)
    return a.start < b.start
  end)

  return tokens
end

--- get results stats
---@param tokens ResultsToken[]
---@return ParsedResultsStats
local function getStats(tokens)
  local stats = { matches = 0, files = 0 }
  for k = 1, #tokens do
    local token = tokens[k]
    if token.type == token_types.color then
      if token.name == 'match' then
        stats.matches = stats.matches + 1
      end
      if token.name == 'path' then
        stats.files = stats.files + 1
      end
    end
  end

  return stats
end

--- parse results chunk and get info
---@param data string
---@param isSearchWithReplacement boolean
---@return ParsedResultsData
local function parseResults(data, isSearchWithReplacement)
  local tokens = getTokens(data, isSearchWithReplacement)

  local i = 1
  local line = ''
  local highlight = nil
  local lines = {}
  local highlights = {}
  for k = 1, #tokens do
    local token = tokens[k]
    line = line .. string.sub(data, i, token.start - 1)
    i = token.fin + 1
    if token.type == token_types.newline then
      table.insert(lines, utils.getLineWithoutCarriageReturn(line))
      line = ''
    elseif token.type == token_types.color then
      highlight = {
        hl = token.hl,
        hl_type = token.hl_type,
        start_line = #lines,
        start_col = #line,
        sign = token.sign,
      }
    elseif token.type == token_types.color_ending and highlight then
      highlight.end_line = #lines
      highlight.end_col = #line
      table.insert(highlights, highlight)
      highlight = nil
    end
  end
  if i < #data then
    table.insert(lines, string.sub(data, i, #data))
  end

  return { lines = lines, highlights = highlights, stats = getStats(tokens) }
end

return parseResults
