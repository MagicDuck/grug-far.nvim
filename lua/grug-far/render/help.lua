local opts = require('grug-far.opts')
local utils = require('grug-far.utils')

---@alias VirtText string[]

--- gets help virtual text lines
---@param virt_lines VirtText[][]
---@param actions grug.far.Action[]
---@param context grug.far.Context
---@return VirtText[][]
local function getHelpVirtLines(virt_lines, actions, context)
  local entries = vim.tbl_map(function(action)
    return { text = action.text, lhs = utils.getActionMapping(action.keymap) }
  end, actions)
  entries = vim.tbl_filter(function(entry)
    return entry.lhs ~= nil
  end, entries)

  local sep = opts.getIcon('actionEntryBullet', context) or '| '
  local separating_spaces = string.rep(' ', 3)
  local ellipsis = ' ...'
  local available_win_width = vim.api.nvim_win_get_width(0) - #ellipsis - 2
  local current_width = 0
  local line = {}
  for i, entry in ipairs(entries) do
    local entrySize = #entry.text + #entry.lhs + 4
    current_width = current_width + (i == 1 and entrySize or entrySize + #separating_spaces)
    if i > 1 and current_width > available_win_width then
      table.insert(line, { ellipsis })
      break
    end

    if i > 1 then
      table.insert(line, { separating_spaces })
    end
    table.insert(line, { sep .. entry.text .. ' ', 'GrugFarHelpHeader' })
    table.insert(line, { entry.lhs, 'GrugFarHelpHeaderKey' })
  end

  table.insert(virt_lines, line)

  -- one blank line at end
  table.insert(virt_lines, { { '' } })

  return virt_lines
end

---@class grug.far.HelpRenderParams
---@field buf integer
---@field extmarkName string
---@field actions grug.far.Action[]
---@field top_virt_lines? VirtText[][]

---@param params grug.far.HelpRenderParams
---@param context grug.far.Context
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
