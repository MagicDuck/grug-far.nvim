local utils = require('grug-far/utils')
local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')
local getArgs = require('grug-far/engine/astgrep/getArgs')
local parseResults = require('grug-far/engine/astgrep/parseResults')

---@type GrugFarEngine
local AstgrepEngine = {
  type = 'astgrep',

  search = function(params)
    local extraArgs = {}
    local args = getArgs(params.inputs, params.options, extraArgs)

    return fetchCommandOutput({
      cmd_path = params.options.engines.astgrep.path,
      args = args,
      options = params.options,
      on_fetch_chunk = function(data)
        params.on_fetch_chunk(parseResults(data))
      end,
      on_finish = function(status, errorMessage)
        -- TODO (sbadragan): anything we can do for no matches?
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
