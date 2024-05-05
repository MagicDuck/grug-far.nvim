local colors = require('grug-far/rg/colors')

local token_types = {
  color = 1,
  color_ending = 2,
  newline = 3
}

local function getTokens(data)
  local tokens = {}
  local i
  local j

  for name, color in pairs(colors.rg_colors) do
    i = 0
    j = 0
    while true do
      i, j = string.find(data, color.ansi, i + 1, true)
      if i == nil then break end
      table.insert(tokens, {
        type = token_types.color,
        hl = color.hl,
        name = name,
        start = i,
        fin = j
      })
    end
  end

  i = 0
  j = 0
  while true do
    i, j = string.find(data, colors.ansi_color_ending, i + 1, true)
    if i == nil then break end
    table.insert(tokens, { type = token_types.color_ending, start = i, fin = j })
  end

  i = 0
  j = 0
  while true do
    i, j = string.find(data, "\n", i + 1, true)
    if i == nil then break end
    table.insert(tokens, { type = token_types.newline, start = i, fin = j })
  end

  table.sort(tokens, function(a, b) return a.start < b.start end)

  return tokens
end

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


local function parseResults(data)
  local tokens = getTokens(data)

  local i = 1
  local line = ""
  local highlight = nil
  local lines = {}
  local highlights = {}
  for k = 1, #tokens do
    local token = tokens[k]
    line = line .. string.sub(data, i, token.start - 1)
    i = token.fin + 1
    if token.type == token_types.newline then
      table.insert(lines, line)
      line = ""
    elseif token.type == token_types.color then
      highlight = { hl = token.hl, start_line = #lines, start_col = #line }
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
