local opts = require('grug-far/opts')

---@param keymap KeymapDef
---@return string | nil
local function getActionMapping(keymap)
  local lhs = keymap.n
  if not lhs or #lhs == 0 then
    return nil
  end
  if vim.g.maplocalleader then
    lhs = lhs:gsub('<localleader>', vim.g.maplocalleader)
  end
  if vim.g.mapleader then
    lhs = lhs:gsub('<leader>', vim.g.mapleader == ' ' and '< >' or vim.g.mapleader)
  end

  return lhs
end

---@alias VirtText string[]

---@class GrugFarAction
---@field text string
---@field keymap KeymapDef

--- gets help virtual text lines
---@param virt_lines VirtText[][]
---@param actions GrugFarAction[]
---@param context GrugFarContext
---@return VirtText[][]
local function getHelpVirtLines(virt_lines, actions, context)
  local entries = vim.tbl_map(function(action)
    return { text = action.text, lhs = getActionMapping(action.keymap) }
  end, actions)
  entries = vim.tbl_filter(function(entry)
    return entry.lhs ~= nil
  end, entries)

  local maxEntryLen = 0
  for _, entry in ipairs(entries) do
    local entrySize = #entry.text + #entry.lhs + 4
    if entrySize > maxEntryLen then
      maxEntryLen = entrySize
    end
  end

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

---@class HelpRenderParams
---@field buf integer
---@field extmarkName string
---@field actions GrugFarAction[]
---@field top_virt_lines? VirtText[][]

---@param params HelpRenderParams
---@param context GrugFarContext
local function renderHelp(params, context)
  local buf = params.buf
  local actions = params.actions
  local top_virt_lines = params.top_virt_lines or {}
  local extmarkName = params.extmarkName

  local virt_lines = getHelpVirtLines(top_virt_lines, actions, context)
  context.extmarkIds[extmarkName] = vim.api.nvim_buf_set_extmark(buf, context.namespace, 0, 0, {
    id = context.extmarkIds[extmarkName],
    virt_text = virt_lines[1],
    virt_text_pos = 'overlay',
    virt_lines = vim.list_slice(virt_lines, 2),
  })
end

return renderHelp
