local utils = require('grug-far.utils')
local getRgVersion = require('grug-far.engine.ripgrep.getRgVersion')

--- get args for ripgrep or nil if params invalid / insufficient
---@param inputs grug.far.Inputs
---@param options grug.far.Options
---@param extraArgs string[]
---@param blacklistedFlags? string[]
---@param forceReplace? boolean
---@return string[]? args, string[]? blacklisted
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
  local extraUserArgs = vim.trim(options.engines.ripgrep.extraArgs or '')
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

  if #inputs.paths > 0 then
    ---@diagnostic disable-next-line: undefined-field
    local context = options.__grug_far_context__
    local paths = utils.normalizePaths(utils.splitPaths(inputs.paths), context)
    for _, path in ipairs(paths) do
      table.insert(args, path)
    end
  end

  if #blacklisted > 0 then
    return nil, blacklisted
  end

  -- required args
  table.insert(args, '--line-number')
  table.insert(args, '--heading')
  table.insert(args, '--column')
  table.insert(args, '--max-columns=0')
  table.insert(args, '--field-match-separator=:')
  table.insert(args, '--block-buffered')
  table.insert(args, '--with-filename')

  -- note: --hyperlink-format not supported in rg v13
  local version = getRgVersion(options)
  if version and not vim.version.lt(version, '14') then
    table.insert(args, '--hyperlink-format=none')
  end

  if #inputs.filesFilter > 0 then
    for _, fileFilter in ipairs(vim.split(inputs.filesFilter, '\n')) do
      local glob = vim.trim(fileFilter)
      if utils.is_win then
        -- convert backslashes to forward slashes in glob on windows as globset
        -- does not support windows style paths
        glob = vim.fs.normalize(fileFilter)
      end
      if #glob > 0 then
        table.insert(args, '--glob=' .. glob)
      end
    end
  end

  for i = 1, #extraArgs do
    table.insert(args, extraArgs[i])
  end

  if #inputs.search > 0 then
    table.insert(args, '--regexp=' .. inputs.search:gsub('\n', utils.eol))
  end

  return args, nil
end

return getArgs
