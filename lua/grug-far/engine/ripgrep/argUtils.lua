local M = {}

---@param args string[]?
---@return string[]? newArgs
function M.stripReplaceArgs(args)
  if not args then
    return nil
  end
  local newArgs = {}
  local stripNextArg = false
  for _, arg in ipairs(args) do
    local isOneArgReplace = vim.startswith(arg, '--replace=')
    local isTwoArgReplace = arg == '--replace' or arg == '-r'
    local stripArg = stripNextArg or isOneArgReplace or isTwoArgReplace
    stripNextArg = isTwoArgReplace

    if not stripArg then
      table.insert(newArgs, arg)
    end
  end

  return newArgs
end

return M
