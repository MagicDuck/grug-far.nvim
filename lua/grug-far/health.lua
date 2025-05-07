local is_win = vim.api.nvim_call_function('has', { 'win32' }) == 1

local M = {}

---@class grug.far.Dependency
---@field name string
---@field url string
---@field optional boolean
---@field binaries? string[]

---@type grug.far.Dependency[]
local dependencies = {
  {
    name = 'rg',
    url = '[BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)',
    optional = false,
  },
  {
    name = 'ast-grep',
    url = '[ast-grep](https://ast-grep.github.io)',
    optional = true,
  },
}

---@param dep grug.far.Dependency
local function check_binary_installed(dep)
  local binaries = dep.binaries or { dep.name }
  for _, binary in ipairs(binaries) do
    if is_win then
      binary = binary .. '.exe'
    end
    if vim.fn.executable(binary) == 1 then
      local binary_version = '(unknown version)'
      local handle = io.popen(binary .. ' --version')
      if handle then
        binary_version = handle:read('*a')
        local eol = binary_version:find('\n')
        if eol then
          binary_version = binary_version:sub(1, eol - 1)
        end
        handle:close()
      end
      return true, binary_version
    end
  end
end

function M.check()
  vim.health.start('Checking external dependencies')

  for _, dep in pairs(dependencies) do
    local installed, version = check_binary_installed(dep)
    if not installed then
      local err_msg = ('%s: not found.'):format(dep.name)
      if dep.optional then
        vim.health.warn(
          ('%s %s'):format(err_msg, ('Install %s for extended capabilities'):format(dep.url))
        )
      else
        vim.health.error(
          ('%s %s'):format(
            err_msg,
            ('`GrugFar` will not function without %s installed.'):format(dep.url)
          )
        )
      end
    else
      vim.health.ok(('%s: found %s'):format(dep.name, version))
    end
  end
end

return M
