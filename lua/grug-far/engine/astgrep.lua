local utils = require('grug-far/utils')

---@type GrugFarEngine
local AstgrepEngine = {
  type = 'astgrep',

  search = function(params)
    local extraArgs = { '--color=ansi' }
    for k, v in pairs(colors.rg_colors) do
      table.insert(extraArgs, '--colors=' .. k .. ':none')
      table.insert(extraArgs, '--colors=' .. k .. ':fg:' .. v.rgb)
    end

    local args = getArgs(params.inputs, params.options, extraArgs)

    return fetchCommandOutput({
      cmd_path = params.options.engines.ripgrep.path,
      args = args,
      options = params.options,
      on_fetch_chunk = function(data)
        params.on_fetch_chunk(parseResults(data))
      end,
      on_finish = function(status, errorMessage)
        if status == 'error' and errorMessage and #errorMessage == 0 then
          errorMessage = 'no matches'
        end
        params.on_finish(status, errorMessage)
      end,
    })
  end,

  replace = function(params)
    -- TODO (sbadragan): implement
  end,

  sync = function(params)
    -- TODO (sbadragan): implement if  possible
  end,

  getInputPrefillsForVisualSelection = function(initialPrefills)
    -- TODO (sbadragan): implement
    return initialPrefills
  end,
}

return AstgrepEngine
