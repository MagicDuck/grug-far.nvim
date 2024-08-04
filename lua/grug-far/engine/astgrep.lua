local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')
local getArgs = require('grug-far/engine/astgrep/getArgs')
local parseResults = require('grug-far/engine/astgrep/parseResults')

--- decodes streamed json matches, appending to given table
---@param matches AstgrepMatch[]
---@param data string
local function json_decode_matches(matches, data)
  local json_lines = vim.split(data, '\n')
  for _, json_line in ipairs(json_lines) do
    if #json_line > 0 then
      local match = vim.json.decode(json_line)
      table.insert(matches, match)
    end
  end
end

--- splits off matches corresponding to the last file
---@param matches AstgrepMatch[]
---@return AstgrepMatch[] before, AstgrepMatch[] after
local function split_last_file_matches(matches)
  local end_index = 0
  for i = #matches - 1, 1, -1 do
    if matches[i].file ~= matches[i + 1].file then
      end_index = i
      break
    end
  end

  local before = {}
  for i = 1, end_index do
    table.insert(before, matches[i])
  end
  local after = {}
  for i = end_index + 1, #matches do
    table.insert(after, matches[i])
  end

  return before, after
end

---@type GrugFarEngine
local AstgrepEngine = {
  type = 'astgrep',

  search = function(params)
    local extraArgs = {
      '--json=stream',
    }
    local args = getArgs(params.inputs, params.options, extraArgs)

    local hadOutput = false
    local matches = {}
    return fetchCommandOutput({
      cmd_path = params.options.engines.astgrep.path,
      args = args,
      options = params.options,
      on_fetch_chunk = function(data)
        hadOutput = true
        json_decode_matches(matches, data)
        -- note: we split off last file matches to ensure all matches for a file are processed
        -- at once. This helps with applying replacements
        local before, after = split_last_file_matches(matches)
        matches = after
        params.on_fetch_chunk(parseResults(before))
      end,
      on_finish = function(status, errorMessage)
        if #matches > 0 then
          -- do the last few
          params.on_fetch_chunk(parseResults(matches))
          matches = {}
        end

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
