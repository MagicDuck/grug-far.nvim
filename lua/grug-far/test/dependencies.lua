local M = {}

local NVIM_VERSION = '0.11.0'
local RG_VERSION = '14.1.0'
local SG_VERSION = '0.35.0'

--- checks if it has required version of executable
---@param path string
---@param required_version string
---@return boolean
local function has_required_version(path, required_version)
  local has_exe = false
  if vim.uv.fs_stat(path) then
    local version = vim.version.parse(vim.fn.system({ path, '--version' }), { strict = false })
    version.prerelease = nil
    version.build = nil
    has_exe = (not not version) and vim.version.eq(version, required_version)
  end

  return has_exe
end

function M.checkDependencies()
  local has_deps = true

  if not vim.version.eq(vim.version(), NVIM_VERSION) then
    print(
      '\n**Warning**\n'
        .. 'nvim '
        .. NVIM_VERSION
        .. " recommended for running the tests. It's possible results might differ slightly from CI otherwise.\n"
        .. "You can also run the tests with a different nvim with 'make test nvim_path=...'"
        .. '\n\n'
    )
  end

  local has_run_prepare = vim
    .iter({ 'deps/mini.nvim', 'temp_test_dir', 'temp_history_dir' })
    :all(function(path)
      return not not (vim.uv.fs_stat(vim.fs.abspath(path)))
    end)
  if not has_run_prepare then
    print('\nPlease run "make prepare"\n\n')
    has_deps = false
  end

  if not has_required_version(vim.fs.abspath('deps/ripgrep/rg'), RG_VERSION) then
    print(
      '\n**Error**\n'
        .. 'Please get ripgrep '
        .. RG_VERSION
        .. ' and place executable at deps/ripgrep/rg\n'
        .. 'You can download it from https://github.com/BurntSushi/ripgrep/releases/tag/'
        .. RG_VERSION
        .. '\n\n'
    )
    has_deps = false
  end

  if not has_required_version(vim.fs.abspath('deps/astgrep/ast-grep'), SG_VERSION) then
    print(
      '\n**Error**\n'
        .. 'Please get ast-grep '
        .. SG_VERSION
        .. ' and place executable at deps/astgrep/ast-grep\n'
        .. 'You can download it from https://github.com/ast-grep/ast-grep/releases/tag/'
        .. SG_VERSION
        .. '\n\n'
    )
    has_deps = false
  end

  if not has_deps then
    error('Could not find all test dependencies!')
  end
end

return M
