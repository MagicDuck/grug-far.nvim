local uv = vim.loop

local function process_data_chunk(data)
  -- TODO (sbadragan): implement
  return vim.split(data, '\n')
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
    table.insert(args, '--colors=match:bg:0,128,255')
  end

  if not args then
    return
  end

  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  -- TODO (sbadragan): proper spawn
  -- rg local --replace=bob --context=1 --heading --json --glob='*.md' ./
  -- TODO (sbadragan): just rg?
  -- local _, pid = uv.spawn("/opt/homebrew/bin/rg", {
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
    -- TODO (sbadragan): remove?
    P('killed proc')
    stdout:close()
    stderr:close()
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
