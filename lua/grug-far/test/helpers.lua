local M = {}

-- { 8, 5, 0, {
--       end_col = 0,
--       end_right_gravity = false,
--       end_row = 5,
--       ns_id = 5,
--       right_gravity = false,
--       virt_lines = { { { " 󰮚 Flags:", "GrugFarInputLabel" } } },
--       virt_lines_above = true,
--       virt_lines_leftcol = true
--     }
-- TODO (sbadragan): add more helpers here

--- get list of virtual text chunks associated with given namespace in given buffer
---@param buf integer
---@param namespaceName string
---@return string[]
function M.getBufExtmarksVirtText(buf, namespaceName)
  local namespace = vim.api.nvim_create_namespace(namespaceName)
  local marks = vim.api.nvim_buf_get_extmarks(
    buf,
    namespace,
    { 0, 0 },
    { -1, -1 },
    { details = true }
  )

  local textChunks = {}

  for i = 1, #marks do
    local _, _, _, details = unpack(marks[i])
    local virt_lines = details.virt_lines
    if virt_lines then
      for j = 1, #virt_lines do
        local line = virt_lines[j]
        for k = 1, #line do
          local chunk = line[k]
          local text = unpack(chunk)
          table.insert(textChunks, text)
        end
      end
    end

    local virt_text = details.virt_text
    if virt_text then
      for l = 1, #virt_text do
        local chunk = virt_text[l]
        local text = unpack(chunk)
        table.insert(textChunks, text)
      end
    end
  end

  return textChunks
end

--- checks if virtual text associated with given namespace contains given string
---@param namespaceName string
---@param str string
---@return boolean
function M.bufVirtualTextContains(namespaceName, str)
  local textChunks = M.getBufExtmarksVirtText(0, namespaceName)
  for i = 1, #textChunks do
    local text = textChunks[i]
    if text:find(str, 1, true) then
      return true
    end
  end

  return false
end

---@alias NeovimChild any

--- checks if child neovim contains the given string
--- in the grug-far buffer UI namespace
---@param child NeovimChild
---@param str string
---@return boolean
function M.childBufUIVirtualTextContains(child, str)
  return child.lua_get('Helpers.bufVirtualTextContains(...)', { 'grug-far-namespace', str })
end

--- waits until condition fn evals to true, checking every interval ms
--- times otu at timeout ms
---@param condition fun(): boolean
---@param timeout? integer, defaults to 2000
---@param interval? integer, defaults to 100
function M.waitForCondition(condition, timeout, interval)
  local max = timeout or 2000
  local inc = interval or 100
  for _ = 0, max, inc do
    if condition() then
      return
    else
      vim.loop.sleep(inc)
    end
  end

  error('Timed out waiting for condition after ' .. max .. 'ms!')
end

--- init the child neovim process
---@param child NeovimChild
function M.initChildNeovim(child)
  -- Restart child process with custom 'init.lua' script
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  local rgPath = vim.env.RG_PATH or 'rg'

  child.lua(
    [[ 
    GrugFar = require('grug-far')
    GrugFar.setup(...)
    Helpers = require('grug-far/test/helpers')
  ]],
    {
      ---@type GrugFarOptions
      {
        rgPath = rgPath,
        -- one thread so that we get things in the same order
        extraRgArgs = '--threads=1',
        icons = {
          resultsStatusReady = 'STATUS_READY',
          resultsStatusError = 'STATUS_ERROR',
          resultsStatusSuccess = 'STATUS_SUCCESS',
        },
      },
    }
  )
end

--- waits until child buf has given status
---@param child NeovimChild
---@param status "STATUS_SUCCESS" | "STATUS_READY" | "STATUS_ERROR"
function M.childWaitForStatus(child, status)
  M.waitForCondition(function()
    return M.childBufUIVirtualTextContains(child, status)
  end)
end

--- run grug_far(options) in child
---@param child NeovimChild
---@param options GrugFarOptionsOverride
function M.childRunGrugFar(child, options)
  local cwd = vim.loop.cwd()
  child.lua('vim.api.nvim_set_current_dir("' .. cwd .. '/temp_test_dir")')
  child.lua('GrugFar.grug_far(...)', {
    options,
  })
end

--- writes files given based on given spec to temp test dir
--- clears out temp test dir beforehand
---@param files {[string]: string}
function M.writeTestFiles(files)
  vim.fn.delete('./temp_test_dir', 'rf')
  vim.fn.mkdir('./temp_test_dir')
  for i = 1, #files do
    local file = files[i]
    vim.fn.writefile(vim.split(file.content, '\n'), './temp_test_dir/' .. file.filename)
  end
end

-- NOTE: for testing uncomment the following line, then open a grug-far buffer and execute
-- :luafile lua/grug-far/test/helpers.lua
-- P(M.bufVirtualTextContains('grug-far-namespace', 'Search'))

return M
