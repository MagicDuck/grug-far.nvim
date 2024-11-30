local utils = require('grug-far.utils')
local getAstgrepVersion = require('grug-far.engine.astgrep.getAstgrepVersion')

local rewriteFlags = {
  '--rewrite',
  '-r',
}

--- get args for astgrep or nil if params invalid / insufficient
---@param inputs GrugFarInputs
---@param options GrugFarOptions
---@param extraArgs string[]
---@param blacklistedFlags? string[]
---@param forceReplace? boolean
---@return string[]? args, string[]? blacklisted
local function getArgs(inputs, options, extraArgs, blacklistedFlags, forceReplace)
  if #inputs.search < (options.minSearchChars or 1) then
    return nil
  end

  local args = { 'run' }

  if forceReplace or #inputs.replacement > 0 then
    table.insert(args, '--rewrite=' .. inputs.replacement)
  end

  -- user overrides
  local blacklisted = {}
  local extraUserArgs = vim.trim(options.engines.astgrep.extraArgs or '')
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
      local skipCheck = forceReplace and utils.isBlacklistedFlag(flag, rewriteFlags)

      if not skipCheck then
        if utils.isBlacklistedFlag(flag, blacklistedFlags) then
          table.insert(blacklisted, flag)
        else
          table.insert(args, flag)
        end
      end
    end
  end

  if #inputs.paths > 0 then
    local paths = utils.splitPaths(inputs.paths)
    for _, path in ipairs(paths) do
      if not vim.startswith(path, '.') then
        path = vim.fs.normalize(path)
      end
      table.insert(args, path)
    end
  end

  if #blacklisted > 0 then
    return nil, blacklisted
  end

  -- required args
  table.insert(args, '--heading=always')
  table.insert(args, '--color=never')

  for i = 1, #extraArgs do
    table.insert(args, extraArgs[i])
  end

  local version = getAstgrepVersion(options)
  -- note: astgrep added --glob suport in v0.28.0
  if #inputs.filesFilter > 0 and version and vim.version.gt(version, '0.27.999') then
    for _, fileFilter in ipairs(vim.split(inputs.filesFilter, '\n')) do
      local glob = vim.trim(fileFilter)
      if #glob > 0 then
        table.insert(args, '--globs=' .. glob)
      end
    end
  end

  table.insert(args, '--pattern=' .. inputs.search)

  return args, nil
end

return getArgs
