local function isProperFlag(arg)
  return vim.startswith(arg, '-') and arg ~= '--'
end

local function isBlacklistedFlag(flag, blacklistedFlags)
  if not blacklistedFlags then
    return false
  end

  for i = 1, #blacklistedFlags do
    local badFlag = blacklistedFlags[i]
    if flag == badFlag or vim.startswith(flag, badFlag .. ' ') or vim.startswith(flag, badFlag .. '=') then
      return true
    end
  end

  return false
end

local function getArgs(inputs, options, extraArgs, blacklistedFlags)
  local args = nil
  if #inputs.search < (options.minSearchChars or 1) then
    return nil
  end

  args = {}

  -- user overridable args
  table.insert(args, '--line-number')
  table.insert(args, '--column')

  -- user overrides
  local extraUserArgs = options.extraRgArgs and vim.trim(options.extraRgArgs) or ''
  if #extraUserArgs > 0 then
    for arg in string.gmatch(extraUserArgs, "%S+") do
      if isBlacklistedFlag(arg, blacklistedFlags) then
        return nil
      end
      if isProperFlag(arg) then
        table.insert(args, arg)
      end
    end
  end

  if #inputs.flags > 0 then
    for flag in string.gmatch(inputs.flags, "%S+") do
      if isBlacklistedFlag(flag, blacklistedFlags) then
        return nil
      end
      if isProperFlag(flag) then
        table.insert(args, flag)
      end
    end
  end

  -- required args
  table.insert(args, '--heading')

  if #inputs.replacement > 0 then
    table.insert(args, '--replace=' .. inputs.replacement)
  end

  if #inputs.filesGlob > 0 then
    table.insert(args, '--glob=' .. inputs.filesGlob)
  end

  for i = 1, #extraArgs do
    table.insert(args, extraArgs[i])
  end

  table.insert(args, '--regexp=' .. inputs.search)

  return args
end

return getArgs
