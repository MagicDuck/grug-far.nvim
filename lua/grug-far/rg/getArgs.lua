local colors = require('grug-far/rg/colors')

local function getArgs(inputs, options)
  local args = nil
  if #inputs.search < (options.minSearchChars or 1) then
    return nil
  end

  args = { inputs.search }
  if #inputs.replacement > 0 then
    table.insert(args, '--replace=' .. inputs.replacement)
  end

  if #inputs.filesGlob > 0 then
    table.insert(args, '--glob=' .. inputs.filesGlob)
  end

  table.insert(args, '--heading')
  table.insert(args, '--line-number')
  table.insert(args, '--column')

  -- colors so that we can show nicer output
  table.insert(args, '--color=ansi')
  for k, v in pairs(colors.rg_colors) do
    table.insert(args, '--colors=' .. k .. ':none')
    table.insert(args, '--colors=' .. k .. ':fg:' .. v.rgb)
  end

  local extraRgArgs = options.extraRgArgs and vim.trim(options.extraRgArgs) or ''
  if #extraRgArgs > 0 then
    for arg in string.gmatch(extraRgArgs, "%S+") do
      table.insert(args, arg)
    end
  end

  -- user provided flags should come last
  if #inputs.flags > 0 then
    for flag in string.gmatch(inputs.flags, "%S+") do
      table.insert(args, flag)
    end
  end

  return args
end

return getArgs
