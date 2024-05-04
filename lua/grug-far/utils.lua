local M = {}

local uv = vim.loop
function M.setTimeout(callback, timeout)
  local timer = uv.new_timer()
  timer:start(timeout, 0, function()
    timer:stop()
    timer:close()
    vim.schedule(callback)
  end)
  return timer
end

function M.clearTimeout(timer)
  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

function M.debounce(callback, timeout)
  local timer
  return function(params)
    M.clearTimeout(timer)
    timer = M.setTimeout(function()
      callback(params)
    end, timeout)
  end
end

return M
