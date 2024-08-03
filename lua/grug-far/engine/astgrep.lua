local utils = require('grug-far/utils')
local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')
local getArgs = require('grug-far/engine/astgrep/getArgs')
local parseResults = require('grug-far/engine/astgrep/parseResults')

---@type GrugFarEngine
local AstgrepEngine = {
  type = 'astgrep',

  search = function(params)
    local extraArgs = {
      '--json=stream',
    }
    local args = getArgs(params.inputs, params.options, extraArgs)

    local hadOutput = false
    return fetchCommandOutput({
      cmd_path = params.options.engines.astgrep.path,
      args = args,
      options = params.options,
      on_fetch_chunk = function(data)
        hadOutput = true
        params.on_fetch_chunk(parseResults(data))
      end,
      on_finish = function(status, errorMessage)
        -- give the user more feedback when there are no matches
        if status == 'success' and not (errorMessage and #errorMessage > 0) and not hadOutput then
          status = 'error'
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
