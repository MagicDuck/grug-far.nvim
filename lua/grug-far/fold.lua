local M = {}

M.getFoldLevel = function(lnum)
  local line = vim.fn.getline(lnum)
  if line and #line > 0 and (line:match('^(%d+:%d+:)') or line:match('^(%d+%-)')) then
    return 1
  end

  return 0
end

return M
