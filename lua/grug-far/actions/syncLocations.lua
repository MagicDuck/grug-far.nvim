local resultsList = require('grug-far/render/resultsList')

-- TODO (sbadragan): what is the idea here?
-- 1. create new action and add keybind
-- 2. resultLocationByExtmarkId, add the line string to it
-- 3. on action invocation, loop through all locations that have line number
-- 4. write associated line to file
local function syncLocations(params)
  local buf = params.buf
  local context = params.context

  local extmarks = vim.api.nvim_buf_get_extmarks(0, context.locationsNamespace, 0, -1, {})
  local changedLines = {}
  for i = 1, #extmarks do
    local markId, row = unpack(extmarks[i])
    local location = context.state.resultLocationByExtmarkId[markId]

    if location and location.rgResultLine then
      local bufline = unpack(vim.api.nvim_buf_get_lines(buf, row, row + 1, true))
      if bufline ~= location.rgResultLine then
        local numColPrefix = string.sub(location.rgResultLine, 1, location.rgColEndIndex + 1)
        if vim.startswith(bufline, numColPrefix) then
          table.insert(changedLines, {
            location = location,
            -- note, skips (:)
            line = string.sub(bufline, location.rgColEndIndex + 2, -1)
          })
        end
      end
    end
  end

  P(changedLines)
end

return syncLocations
