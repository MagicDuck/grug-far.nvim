local uv = vim.loop

-- TODO (sbadragan): what should we display when there is no search?
local function rgFetchResults(params)
  local on_fetch_chunk = params.on_fetch_chunk
  local inputs = params.inputs

  -- TODO (sbadragan): use uv.spawn() to spawn rg process with
  -- rg local --replace=bob --context=1 --heading --json --glob='*.md' ./
  on_fetch_chunk("hello from rg fetcher")
  P(inputs)
end

return rgFetchResults

-- local stdin = uv.new_pipe()
-- local stdout = uv.new_pipe()
-- local stderr = uv.new_pipe()
--
-- print("stdin", stdin)
-- print("stdout", stdout)
-- print("stderr", stderr)
--
-- local handle, pid = uv.spawn("cat", {
--   stdio = { stdin, stdout, stderr }
-- }, function(code, signal) -- on exit
--   print("exit code", code)
--   print("exit signal", signal)
-- end)
--
-- print("process opened", handle, pid)
--
-- uv.read_start(stdout, function(err, data)
--   assert(not err, err)
--   if data then
--     print("stdout chunk", stdout, data)
--   else
--     print("stdout end", stdout)
--   end
-- end)
--
-- uv.read_start(stderr, function(err, data)
--   assert(not err, err)
--   if data then
--     print("stderr chunk", stderr, data)
--   else
--     print("stderr end", stderr)
--   end
-- end)
--
-- uv.write(stdin, "Hello World")
--
-- uv.shutdown(stdin, function()
--   print("stdin shutdown", stdin)
--   uv.close(handle, function()
--     print("process closed", handle, pid)
--   end)
-- end)
