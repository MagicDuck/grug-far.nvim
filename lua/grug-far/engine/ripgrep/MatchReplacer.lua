local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')
local uv = vim.uv

---@class MatchReplacer
---@field _stdin uv_pipe_t
---@field _replaced_lines? string
---@field _on_done? fun(replaced_lines: string)
local M = {}

M.__index = M

--- creates a ripgrep process that will read given lines from stdin and
--- perform replace on them
---@param options GrugFarOptions
---@param args string[]
---@param on_err fun(err: string)
function M.new(options, args, on_err)
  local self = setmetatable({}, M)
  self._stdin = uv.new_pipe()
  self._replaced_lines = nil
  self._on_done = nil

  P(args)
  fetchCommandOutput({
    cmd_path = options.engines.ripgrep.path,
    args = args,
    stdin = self._stdin,
    on_fetch_chunk = function(data)
      P('on_fetch_chunk')
      if not self._on_done then
        return
      end

      self._replaced_lines = self._replaced_lines and self._replaced_lines .. data or data

      print('data', data)
      if vim.endswith(data, 'XXX') then
        self._on_done(self._replaced_lines:sub(1, -2))
        self._on_done = nil
        self._replaced_lines = nil
      end
    end,
    on_finish = function(status, errorMessage)
      if status == 'error' and errorMessage then
        on_err(errorMessage)
      end
      -- TODO (sbadragan): remove
      print('match replacer finished!', status, errorMessage)
    end,
  })

  return self
end

--- passes the given lines through rg replace
---@param lines string
---@param on_done fun(replaced_lines: string)
function M:get_replaced_lines(lines, on_done)
  self._replaced_lines = nil
  self._on_done = on_done
  P(lines)
  uv.write(self._stdin, lines .. '\0')
end

function M:destroy()
  -- TODO (sbadragan): rmove
  P('destroy is called')
  uv.shutdown(self._stdin)
end

return M
