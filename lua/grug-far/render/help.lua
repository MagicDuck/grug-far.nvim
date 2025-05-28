local opts = require('grug-far.opts')
local utils = require('grug-far.utils')

local M = {}

---@alias grug.far.VirtText string[]

--- gets help virtual text lines
---@param context grug.far.Context
---@param actions grug.far.Action[]
---@return grug.far.VirtText[][]
function M.getHelpVirtLines(context, actions)
  local virt_lines = {}
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

  return virt_lines
end

return M
