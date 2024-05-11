local function printMapping(prefix, lhs)
  return #lhs > 0 and prefix .. lhs or nil
end

local function renderHelp(params, context)
  local buf = params.buf

  local helpExtmarkPos = context.extmarkIds.help and
    vim.api.nvim_buf_get_extmark_by_id(buf, context.namespace, context.extmarkIds.help, {}) or {}
  if helpExtmarkPos[1] ~= 0 then
    local keymaps = context.options.keymaps
    context.extmarkIds.help = vim.api.nvim_buf_set_extmark(buf, context.namespace, 0, 0, {
      id = context.extmarkIds.help,
      end_row = 0,
      end_col = 0,
      virt_text = {
        {
          vim.fn.join(vim.tbl_filter(function(m) return m end, {
            printMapping('Replace: ', keymaps.replace),
            printMapping('Quickfix List: ', keymaps.qflist),
            printMapping('Goto Location: n_', keymaps.gotoLocation),
            printMapping('Sync Edits: ', keymaps.syncLocations),
            printMapping('Close: ', keymaps.close),
          }), ' | '),

          'GrugFarHelpHeader'
        }
      },
      virt_text_pos = 'overlay'
    })
  end
end

return renderHelp
