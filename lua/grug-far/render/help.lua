local opts = require('grug-far/opts')

---@param keymap KeymapDef
---@return string | nil
local function getActionMapping(keymap)
  local lhs = keymap.n
  if not lhs or #lhs == 0 then
    return nil
  end
  lhs = lhs
    :gsub('<localleader>', vim.g.maplocalleader)
    :gsub('<leader>', vim.g.mapleader == ' ' and '< >' or vim.g.mapleader)
  return lhs
end

---@alias VirtText string[]

---@class GrugFarAction
---@field text string
---@field keymap KeymapDef

--- gets help virtual text lines
---@param actions GrugFarAction[]
---@param context GrugFarContext
---@return VirtText[][]
local function getHelpVirtLines(actions, context)
  local entries = vim.tbl_map(function(action)
    return { text = action.text, lhs = getActionMapping(action.keymap) }
  end, actions)

  local maxEntryLen = 0
  for _, entry in ipairs(entries) do
    local entrySize = #entry.text + #entry.lhs + 4
    if entrySize > maxEntryLen then
      maxEntryLen = entrySize
    end
  end

  local virt_lines = {}
  local sep = opts.getIcon('actionEntryBullet', context) or '| '
  local headerMaxWidth = context.options.headerMaxWidth
  local entries_per_line = math.floor(headerMaxWidth / maxEntryLen)

  local line = {}
  for i, entry in ipairs(entries) do
    table.insert(line, { sep .. entry.text .. ' ', 'GrugFarHelpHeader' })
    table.insert(line, { entry.lhs, 'GrugFarHelpHeaderKey' })
    table.insert(line, { string.rep(' ', maxEntryLen - #sep - #entry.text - #entry.lhs + 3) })
    if i % entries_per_line == 0 or i == #entries then
      table.insert(virt_lines, line)
      line = {}
    end
  end
  return virt_lines
end

---@param params { buf: integer, actions: GrugFarAction[] }
---@param context GrugFarContext
local function renderHelp(params, context)
  local buf = params.buf
  local actions = params.actions

  local virt_lines = getHelpVirtLines(actions, context)
  context.extmarkIds.help = vim.api.nvim_buf_set_extmark(buf, context.namespace, 0, 0, {
    id = context.extmarkIds.help,
    virt_text = virt_lines[1],
    virt_text_pos = 'overlay',
    virt_lines = vim.list_slice(virt_lines, 2),
  })
end

return renderHelp
