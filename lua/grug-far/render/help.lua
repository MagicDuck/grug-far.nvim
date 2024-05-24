local opts = require('grug-far/opts')

---@param prefix string
---@param keymap KeymapDef
---@param mode string
---@return string | nil
local function printMapping(prefix, keymap, mode)
  local m = string.sub(mode, 1, 1)
  local lhs = keymap[m]
  return (lhs and #lhs > 0) and prefix .. ' ' .. lhs or nil
end

local function getHelpVirtLines(context)
  local keymaps = context.options.keymaps
  local mode = vim.fn.mode()
  local entries = vim.tbl_filter(function(m)
    return m
  end, {
    printMapping('Replace', keymaps.replace, mode),
    printMapping('Sync All', keymaps.syncLocations, mode),
    printMapping('Sync Line', keymaps.syncLine, mode),
    -- TODO (sbadragan): would need mappings for those
    printMapping('History Open', keymaps.syncLocations, mode),
    printMapping('History Add', keymaps.qflist, mode),

    printMapping('Refresh', keymaps.refresh, mode),
    printMapping('Quickfix', keymaps.qflist, mode),
    printMapping('Goto', keymaps.gotoLocation, mode),
    printMapping('Close', keymaps.close, mode),
  })

  local maxEntryLen = 0
  for _, entry in ipairs(entries) do
    if #entry > maxEntryLen then
      maxEntryLen = #entry
    end
  end

  local virt_lines = {}
  local sep = opts.getIcon('actionEntryBullet', context) or '| '
  local max_width = 100
  local entries_per_line = math.floor(max_width / maxEntryLen)

  local line = ''
  for i, entry in ipairs(entries) do
    local newLine = line .. sep .. string.format('%-' .. maxEntryLen .. 's', entry) .. '  '
    if i == entries_per_line or i == #entries then
      table.insert(virt_lines, { { newLine, 'GrugFarHelpHeader' } })
      line = ''
    else
      line = newLine
    end
  end

  return virt_lines
end

---@param params { buf: integer }
---@param context GrugFarContext
local function renderHelp(params, context)
  local buf = params.buf

  context.extmarkIds.help1 = vim.api.nvim_buf_set_extmark(buf, context.namespace, 0, 0, {
    id = context.extmarkIds.help1,
    virt_lines = getHelpVirtLines(context),
  })
end

return renderHelp
