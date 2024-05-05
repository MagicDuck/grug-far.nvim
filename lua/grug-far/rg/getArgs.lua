local colors = require('grug-far/rg/colors')

local function getArgs(inputs)
  local args = nil
  if #inputs.search == 0 then
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

  -- TODO (sbadragan): add option for extra rg args, or maybe just show number?
  -- table.insert(args, '--line-number')

  -- user provided flags should come last
  if #inputs.flags then
    for flag in string.gmatch(inputs.flags, "%S+") do
      table.insert(args, flag)
    end
  end

  return args
end

return getArgs
