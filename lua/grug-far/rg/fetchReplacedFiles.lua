local getArgs = require('grug-far/rg/getArgs')
local fetchWithRg = require('grug-far/rg/fetchWithRg')

-- TODO (sbadragan): need to figure where to show this in the UI, aborting, etc
-- possibly in the results list header, show "Applying changes, buffer not modifiable meanwhile"
-- and set nomodifiable for buffer
-- need to call this with proper params from somewhere
local function fetchReplacedFiles(params)
  local args = getArgs(params.inputs, params.options)
  if args then
    table.insert(args, '--passthrough')
    table.insert(args, '--null')
    table.insert(args, '--no-line-number')
    table.insert(args, '--color=never')

    for i = 1, #params.files do
      table.insert(args, params.files[i])
    end
  end
  P(args)

  return fetchWithRg({
    args = args,
    -- TODO (sbadragan): wrapping this with vim.schedule at lowest level is probably bad
    -- remove that
    on_fetch_chunk = function(data)
      local parts = vim.split(data, "\0")
      params.on_fetch_chunk({
        file = parts[1],
        contents = parts[2]
      })
    end,
    on_finish = params.on_finish
  })
end

return fetchReplacedFiles
