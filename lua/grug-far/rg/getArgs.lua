local utils = require('grug-far/utils')

--- get args for ripgrep or nil if params invalid / insufficient
---@param inputs GrugFarInputs
---@param options GrugFarOptions
---@param extraArgs string[]
---@param blacklistedFlags? string[]
---@param forceReplace? boolean
---@return string[] | nil args, string[] | nil blacklisted
local function getArgs(inputs, options, extraArgs, blacklistedFlags, forceReplace)
  if #inputs.search < (options.minSearchChars or 1) then
    return nil
  end

  local args = {}

  if forceReplace or #inputs.replacement > 0 then
    table.insert(args, '--replace=' .. inputs.replacement)
  end

  -- user overrides
  local blacklisted = {}
  local extraUserArgs = options.extraRgArgs and vim.trim(options.extraRgArgs) or ''
  if #extraUserArgs > 0 then
    for arg in string.gmatch(extraUserArgs, '%S+') do
      if utils.isBlacklistedFlag(arg, blacklistedFlags) then
        table.insert(blacklisted, arg)
      else
        table.insert(args, arg)
      end
    end
  end

  if #inputs.flags > 0 then
    for flag in string.gmatch(inputs.flags, '%S+') do
      if utils.isBlacklistedFlag(flag, blacklistedFlags) then
        table.insert(blacklisted, flag)
      else
        table.insert(args, flag)
      end
    end
  end

  if #blacklisted > 0 then
    return nil, blacklisted
  end

  -- required args
  table.insert(args, '--line-number')
  table.insert(args, '--heading')
  table.insert(args, '--column')
  table.insert(args, '--field-match-separator=:')
  table.insert(args, '--block-buffered')
  table.insert(args, '--with-filename')

  if #inputs.filesFilter > 0 then
    table.insert(args, '--glob=' .. inputs.filesFilter)
  end

  for i = 1, #extraArgs do
    table.insert(args, extraArgs[i])
  end

  table.insert(args, '--regexp=' .. inputs.search)

  return args, nil
end

return getArgs
