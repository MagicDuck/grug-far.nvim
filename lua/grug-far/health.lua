local is_win = vim.api.nvim_call_function("has", { "win32" }) == 1

local M = {}

local dependencies = {
  {
    package = {
      {
        name = "rg",
        url = "[BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)",
        optional = false,
      },
    },
  },
}

local check_binary_installed = function(package)
  local binaries = package.binaries or { package.name }
  for _, binary in ipairs(binaries) do
    if is_win then
      binary = binary .. ".exe"
    end
    if vim.fn.executable(binary) == 1 then
      local binary_version = "(unknown version)"
      local handle = io.popen(binary .. " --version")
      if handle then
        binary_version = handle:read("*a")
        local eol = binary_version:find "\n"
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
  vim.health.start("Checking external dependencies")

  for _, dep in pairs(dependencies) do
    for _, package in ipairs(dep.package) do
      local installed, version = check_binary_installed(package)
      if not installed then
        local err_msg = ("%s: not found."):format(package.name)
        if package.optional then
          vim.health.warn(("%s %s"):format(err_msg,
            ("Install %s for extended capabilities"):format(package.url)))
        else
          vim.health.error(
            ("%s %s"):format(
              err_msg,
              ("`GrugFar` will not function without %s installed."):format(package.url)
            )
          )
        end
      else
        vim.health.ok(("%s: found %s"):format(package.name, version))
      end
    end
  end
end

return M
