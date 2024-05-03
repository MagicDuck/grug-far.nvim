local my_cool_module = require("grug-far.my_cool_module")

local M = {}

local function with_defaults(options)
  return {
    resultsHeader = options.resultsHeader or "Results:",
    -- TODO (sbadragan): remove?
    resultsHeaderHighlight = options.resultsHeaderHighlight or "Comment"
  }
end

-- This function is supposed to be called explicitly by users to configure this
-- plugin
function M.setup(options)
  -- avoid setting global values outside of this function. Global state
  -- mutations are hard to debug and test, so having them in a single
  -- function/module makes it easier to reason about all possible changes
  M.options = with_defaults(options or {})

  M.namespace = vim.api.nvim_create_namespace('grug-far.nvim')
  M.extmarkIds = {}

  vim.api.nvim_create_user_command("GrugFar", M.grugFar, {})
end

function M.is_configured()
  return M.options ~= nil
end

local function renderHelp(params)
  local buf = params.buf
  local helpLine = unpack(vim.api.nvim_buf_get_lines(buf, 0, 1, false))
  if #helpLine ~= 0 then
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "" })
  end

  local helpExtmarkPos = M.extmarkIds.help and
    vim.api.nvim_buf_get_extmark_by_id(buf, M.namespace, M.extmarkIds.help, {}) or {}
  if helpExtmarkPos[1] ~= 0 then
    M.extmarkIds.help = vim.api.nvim_buf_set_extmark(buf, M.namespace, 0, 0, {
      id = M.extmarkIds.help,
      end_row = 0,
      end_col = 0,
      virt_text = {
        { "Press g? for help", 'Comment' }
      },
      virt_text_pos = 'overlay'
    })
  end
end

local function str_starts_with(str, start)
  return str:sub(1, #start) == start
end

local function getResultsHeaderRow(buf, lines)
  for i = 1, #lines do
    if str_starts_with(lines[i], M.options.resultsHeader) then
      return i - 1
    end
  end

  return -1
end

local function renderResults(params)
  local buf = params.buf
  local minLineNr = params.minLineNr

  -- TODO (sbadragan): not sure if this would be performance issue in large buffers....
  -- local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- local resultsHeaderRow = getResultsHeaderRow(buf, lines)
  -- if resultsHeaderRow < 0 then
  --   vim.api.nvim_buf_set_lines(buf, resultsHeaderRow, resultsHeaderRow, false, { M.options.resultsHeader })
  --   resultsHeaderRow = #lines
  --   vim.api.nvim_buf_add_highlight(buf, M.namespace, M.options.resultsHeaderHighlight, resultsHeaderRow, 0, -1)
  -- end

  local headerRow = unpack(M.extmarkIds.results_header and
    vim.api.nvim_buf_get_extmark_by_id(buf, M.namespace, M.extmarkIds.results_header, {}) or {})
  local newHeaderRow = nil
  if headerRow == nil or headerRow < minLineNr then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _ = #lines, minLineNr do
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
    end

    newHeaderRow = minLineNr
  end

  if newHeaderRow ~= nil then
    M.extmarkIds.results_header = vim.api.nvim_buf_set_extmark(buf, M.namespace, newHeaderRow, 0, {
      id = M.extmarkIds.results_header,
      end_row = newHeaderRow,
      end_col = 0,
      virt_lines = {
        { { "  ------------------------------", 'SpecialComment' } },
      },
      virt_lines_leftcol = true,
      virt_lines_above = false,
      right_gravity = false
    })
  end
end

local function renderInput(params)
  local buf = params.buf
  local lineNr = params.lineNr
  local extmarkName = params.extmarkName
  local label_virt_lines = params.label_virt_lines

  local line = unpack(vim.api.nvim_buf_get_lines(buf, lineNr, lineNr + 1, false))
  if line == nil then
    vim.api.nvim_buf_set_lines(buf, lineNr, lineNr, false, { "" })
  end

  if label_virt_lines then
    local labelExtmarkName = extmarkName .. "_label"
    local labelExtmarkPos = M.extmarkIds[labelExtmarkName] and
      vim.api.nvim_buf_get_extmark_by_id(buf, M.namespace, M.extmarkIds[labelExtmarkName], {}) or {}
    if labelExtmarkPos[1] ~= lineNr then
      M.extmarkIds[labelExtmarkName] = vim.api.nvim_buf_set_extmark(buf, M.namespace, lineNr, 0, {
        id = M.extmarkIds[labelExtmarkName],
        end_row = lineNr,
        end_col = 0,
        virt_lines = label_virt_lines,
        virt_lines_leftcol = true,
        virt_lines_above = true,
        right_gravity = false
      })
    end
  end
end

local function onBufferChange(params)
  local buf = params.buf

  renderHelp({ buf = buf })
  renderInput({
    buf = buf,
    lineNr = 1,
    extmarkName = "search",
    label_virt_lines = {
      { { "  Search", 'DiagnosticInfo' } },
    },
  })
  renderInput({
    buf = buf,
    lineNr = 2,
    extmarkName = "replace",
    label_virt_lines = {
      { { "  Replace", 'DiagnosticInfo' } },
    },
  })
  renderInput({
    buf = buf,
    lineNr = 3,
    extmarkName = "files_filter",
    label_virt_lines = {
      { { " 󱪣 Files", 'DiagnosticInfo' } },
    },
  })
  renderInput({
    buf = buf,
    lineNr = 4,
    extmarkName = "flags",
    label_virt_lines = {
      { { "  Flags", 'DiagnosticInfo' } },
    },
  })
  renderResults({
    buf = buf,
    minLineNr = 6,
  })
end

-- public API
function M.grugFar()
  if not M.is_configured() then
    return
  end

  -- create split buffer
  vim.cmd('vsplit')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Grug Find and Replace')
  vim.api.nvim_win_set_buf(win, buf)

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = onBufferChange
  })

  -- add lines
  -- vim.api.nvim_buf_set_lines(buf, 0, 0, false, {
  --   "", -- search
  --   "", -- replace
  --   ""  -- flags
  -- })
  -- add virtual text
  -- vim.api.nvim_buf_set_extmark(buf, M.namespace, 0, 0, {
  --   end_row = 0,
  --   end_col = 0,
  --   virt_text = {
  --     { " --help", 'DiagnosticInfo' }
  --   },
  --   virt_text_pos = 'overlay'
  -- })
  -- vim.api.nvim_buf_set_extmark(buf, M.namespace, 1, 0, {
  --   end_row = 1,
  --   end_col = 0,
  --   virt_lines = {
  --     { { "  Search", 'DiagnosticInfo' } },
  --   },
  --   virt_lines_leftcol = true,
  --   virt_lines_above = true,
  --   right_gravity = false
  -- })
  -- vim.api.nvim_buf_set_extmark(buf, M.namespace, 2, 0, {
  --   end_row = 2,
  --   end_col = 0,
  --   -- TODO (sbadragan): create our own highlight group?
  --   -- virt_lines = { { { "  Search" }, "Comment" } }
  --   -- virt_text_pos = "eol"
  --   virt_lines = {
  --     { { "  Replace", 'DiagnosticInfo' } },
  --   },
  --   virt_lines_leftcol = true,
  --   virt_lines_above = true,
  --   right_gravity = false
  -- })
  -- TODO (sbadragan): update marks on TextChanged, TextChangedI

  -- TODO (sbadragan): remove
  -- try to keep all the heavy logic on pure functions/modules that do not
  -- depend on Neovim APIs. This makes them easy to test
  -- local greeting = my_cool_module.greeting(M.options.name)
  -- print(greeting)
end

M.options = nil
return M
