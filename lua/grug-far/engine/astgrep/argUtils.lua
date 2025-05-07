local M = {}

---@param args string[]
---@return string[] newArgs
function M.stripReplaceArgs(args)
  local newArgs = {}
  local stripNextArg = false
  for _, arg in ipairs(args) do
    local isOneArgReplace = vim.startswith(arg, '--rewrite=')
      or arg == '--update-all'
      or arg == '-U'
    local isTwoArgReplace = arg == '--rewrite' or arg == '-r'
    local stripArg = stripNextArg or isOneArgReplace or isTwoArgReplace
    stripNextArg = isTwoArgReplace

    if not stripArg then
      table.insert(newArgs, arg)
    end
  end

  return newArgs
end

return M
