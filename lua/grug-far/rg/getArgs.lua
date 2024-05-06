-- TODO (sbadragan): might need to disable some flags, like:
-- --no-include-zero --no-byte-offset
-- --hyperlink-format=none
-- --max-columns=0
-- --no-max-columns-preview --no-trim
-- blacklist: --help --quiet
-- Hmmm, there are just too many things that could completely screw it up ... I think we need a whitelist of useful
-- flags that we allow the user to pass, otherwise replacing would not work
local function isValidArg(arg)
  return vim.startswith(arg, '-') and arg ~= '--'
end

local function getArgs(inputs, options)
  local args = nil
  if #inputs.search < (options.minSearchChars or 1) then
    return nil
  end

  args = { inputs.search }

  -- user overridable args
  table.insert(args, '--line-number')
  table.insert(args, '--column')

  -- user overrides
  local extraRgArgs = options.extraRgArgs and vim.trim(options.extraRgArgs) or ''
  if #extraRgArgs > 0 then
    for arg in string.gmatch(extraRgArgs, "%S+") do
      if isValidArg(arg) then
        table.insert(args, arg)
      end
    end
  end

  if #inputs.flags > 0 then
    for flag in string.gmatch(inputs.flags, "%S+") do
      if isValidArg(flag) then
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

  return args
end

return getArgs
