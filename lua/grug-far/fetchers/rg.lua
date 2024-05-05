local uv = vim.loop

local ansi_color_ending = '[0m'
local rg_colors = {
  match = {
    rgb = '0,0,0',
    ansi = '[38;2;0;0;0m',
    hl = 'resultsMatch'
  },
  path = {
    rgb = '0,0,1',
    ansi = '[38;2;0;0;1m',
    hl = 'resultsPath'
  },
  line = {
    rgb = '0,0,2',
    ansi = '[38;2;0;0;2m',
    hl = 'resultsLineNo'
  },
}
local token_types = {
  color = 1,
  color_ending = 2,
  newline = 3
}

local function process_data_chunk(data)
  local tokens = {}
  local i
  local j

  for _, color in pairs(rg_colors) do
    i = 0
    j = 0
    while true do
      i, j = string.find(data, color.ansi, i + 1, true)
      if i == nil then break end
      table.insert(tokens, { type = token_types.color, hl = color.hl, start = i, fin = j })
    end
  end

  i = 0
  j = 0
  while true do
    i, j = string.find(data, ansi_color_ending, i + 1, true)
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

  i = 1
  local token
  local line = ""
  local highlight = nil
  local lines = {}
  local highlights = {}
  for k = 1, #tokens do
    token = tokens[k]
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

  return { lines = lines, highlights = highlights }
end

local function rgFetchResults(params)
  local on_fetch_chunk = params.on_fetch_chunk
  local on_finish = params.on_finish
  local on_error = params.on_error
  local inputs = params.inputs

  local args = nil
  -- TODO (sbadragan): minimum search ?
  -- if yes control from higher level and only send here wehn > minsize
  if #inputs.search > 0 then
    args = { inputs.search }
    if #inputs.replacement > 0 then
      table.insert(args, '--replace=' .. inputs.replacement)
    end
    table.insert(args, '--heading')
    -- json_decode({expr})
    -- table.insert(args, '--json')
    if #inputs.filesGlob > 0 then
      table.insert(args, '--glob=' .. inputs.filesGlob)
    end

    if #inputs.flags then
      for flag in string.gmatch(inputs.flags, "%S+") do
        table.insert(args, flag)
      end
    end

    -- colors so that we can show nicer output
    table.insert(args, '--color=ansi')
    for k, v in pairs(rg_colors) do
      table.insert(args, '--colors=' .. k .. ':none')
      table.insert(args, '--colors=' .. k .. ':fg:' .. v.rgb)
    end

    -- TODO (sbadragan): add option for extra rg args, or maybe just show number?
    -- table.insert(args, '--line-number')
  end

  if not args then
    return
  end

  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local handle, pid
  handle, pid = uv.spawn("rg", {
    stdio = { nil, stdout, stderr },
    cwd = vim.fn.getcwd(),
    args = args
  }, function(code, signal)
    stdout:close()
    stderr:close()
    handle:close()
    local isSuccess = code == 0
    on_finish(isSuccess);
  end)

  local on_abort = function()
    stdout:close()
    stderr:close()
    handle:close()
    uv.kill(pid, 'sigkill')
  end

  uv.read_start(stdout, function(err, data)
    if err then
      on_error('rg fetcher: error reading from rg stdout!')
      return
    end

    if data then
      on_fetch_chunk(process_data_chunk(data))
    end
  end)

  uv.read_start(stderr, function(err, data)
    if err then
      on_error('rg fetcher: error reading from rg stderr!')
      return
    end

    if data then
      on_error(data)
    end
  end)

  return on_abort
end

return rgFetchResults
