local function printMapping(prefix, keymap, mode)
  local m = string.sub(mode, 1, 1)
  local lhs = keymap[m]
  return (lhs and #lhs > 0) and prefix .. ' ' .. lhs or nil
end

local function renderHelp(params, context)
  local buf = params.buf
  local mode = vim.fn.mode()

  local keymaps = context.options.keymaps
  context.extmarkIds.help = vim.api.nvim_buf_set_extmark(buf, context.namespace, 0, 0, {
    id = context.extmarkIds.help,
    end_row = 0,
    end_col = 0,
    virt_text = {
      {
        vim.fn.join(
          vim.tbl_filter(function(m)
            return m
          end, {
            printMapping('Replace', keymaps.replace, mode),
            printMapping('Sync All', keymaps.syncLocations, mode),
            printMapping('Sync Line', keymaps.syncLine, mode),
            printMapping('Quickfix', keymaps.qflist, mode),
            printMapping('Goto', keymaps.gotoLocation, mode),
            printMapping('Close', keymaps.close, mode),
          }),
          ' | '
        ),

        'GrugFarHelpHeader',
      },
    },
    virt_text_pos = 'overlay',
  })
end

return renderHelp
