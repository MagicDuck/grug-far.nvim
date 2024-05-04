local utils = require('grug-far/utils')

local abortFetch = nil
local function renderResultList(params)
  local on_start = params.on_start
  local on_fetch_chunk = vim.schedule_wrap(params.on_fetch_chunk)
  local on_finish = vim.schedule_wrap(params.on_finish)
  local on_error = vim.schedule_wrap(params.on_error)
  local inputs = params.inputs
  local context = params.context

  if abortFetch then
    abortFetch();
    abortFetch = nil
  end

  on_start()
  abortFetch = context.options.fetchResults({
    inputs = inputs,
    on_fetch_chunk = on_fetch_chunk,
    on_finish = function()
      abortFetch = nil
      on_finish()
    end,
    on_error = on_error
  })
end

local asyncRenderResultList = nil
local lastInputs = nil
local function renderResults(params, context)
  local buf = params.buf
  local minLineNr = params.minLineNr
  local inputs = params.inputs

  local headerRow = unpack(context.extmarkIds.results_header and
    vim.api.nvim_buf_get_extmark_by_id(buf, context.namespace, context.extmarkIds.results_header, {}) or {})
  local newHeaderRow = nil
  if headerRow == nil or headerRow < minLineNr then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _ = #lines, minLineNr do
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
    end

    newHeaderRow = minLineNr
  end

  -- TODO (sbadragan): maybe show some sort of search status in the virt lines ?
  -- like a clock or a checkmark when replacment has been done?
  -- show some sort of total ?
  if newHeaderRow ~= nil then
    context.extmarkIds.results_header = vim.api.nvim_buf_set_extmark(buf, context.namespace, newHeaderRow, 0, {
      id = context.extmarkIds.results_header,
      end_row = newHeaderRow,
      end_col = 0,
      virt_lines = {
        { { " 󱎸 ──────────────────────────────────────────────────────────", 'SpecialComment' } },
      },
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false
    })
  end
  headerRow = newHeaderRow or headerRow

  if vim.deep_equal(inputs, lastInputs) then
    return
  end
  lastInputs = inputs

  asyncRenderResultList = asyncRenderResultList or utils.debounce(renderResultList, context.options.debounceMs)
  asyncRenderResultList({
    inputs = inputs,
    on_start = function()
      -- remove all lines after heading
      vim.api.nvim_buf_set_lines(buf, headerRow, -1, false, {})
    end,
    on_fetch_chunk = function(chunk_lines)
      -- P(chunk)
      -- TODO (sbadragan): might need some sort of wrapper
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, chunk_lines)
    end,
    on_error = function(err)
      -- TODO (sbadragan): update some sort of status?
      local err_lines = vim.split(err, '\n')
      vim.api.nvim_buf_set_lines(buf, headerRow, headerRow, false, err_lines)

      for i = headerRow, headerRow + #err_lines do
        vim.api.nvim_buf_add_highlight(buf, context.namespace, 'DiagnosticError', i, 0, -1)
      end
    end,
    on_finish = function()
      -- TODO (sbadragan): update some sort of status?
      P('finished')
    end,
    context = context
  })
end

return renderResults
