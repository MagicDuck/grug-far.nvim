local fetchFilesWithMatches = require('grug-far/rg/fetchFilesWithMatches')
local fetchReplacedFiles = require('grug-far/rg/fetchReplacedFiles')

local function replace(buf, context)
  local abort = fetchFilesWithMatches({
    inputs = context.state.inputs,
    options = context.options,
    on_fetch_chunk = function()
    end,
    on_finish = function(status, errorMessage, files)
      -- TODO (sbadragan): temp
      local abort2 = fetchReplacedFiles({
        inputs = context.state.inputs,
        options = context.options,
        files = files,
        on_fetch_chunk = function(replacement)
          -- TODO (sbadragan): we seem to be off by one?
          P(replacement)
        end,
        on_finish = function(status, errorMessage, matches)
          P('finished')
          -- P(status)
          -- P(errorMessage)
          -- for i = 1, #matches do
          --   P(matches[i])
          -- end
        end
      })
    end
  })

  -- TODO (sbadragan): just a test of writing a file, it worked
  -- The idea is to process files with rg --passthrough -N <search> -r <replace> <filepath>
  -- then get the output and write it out to the file using libuv
  -- local f = io.open(
  --   './reactUi/src/pages/IncidentManagement/IncidentDetails/components/PanelDisplayComponents/useIncidentPanelToggle.js',
  --   'w+')
  -- if f then
  --   f:write("stuff")
  --   f:close()
  -- end
end

return replace
