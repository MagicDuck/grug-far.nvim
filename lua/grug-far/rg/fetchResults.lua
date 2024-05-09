local fetchWithRg = require('grug-far/rg/fetchWithRg')
local parseResults = require('grug-far/rg/parseResults')
local getArgs = require('grug-far/rg/getArgs')
local colors = require('grug-far/rg/colors')

local function fetchResults(params)
  local extraArgs = { '--color=ansi' }
  for k, v in pairs(colors.rg_colors) do
    table.insert(extraArgs, '--colors=' .. k .. ':none')
    table.insert(extraArgs, '--colors=' .. k .. ':fg:' .. v.rgb)
  end

  local args = getArgs(params.inputs, params.options, extraArgs)

  return fetchWithRg({
    args = args,
    on_fetch_chunk = function(data)
      params.on_fetch_chunk(parseResults(data))
    end,
    on_finish = params.on_finish
  })
end

return fetchResults
