local blacklistedSearchFlags = require('grug-far.engine.astgrep.blacklistedSearchFlags')

-- those are flags that would result in undesirable situations when replacing
-- (in addition to the blacklisted search flags)
local blacklistedReplaceFlags = {
  '-h',
  '--help',
  '--json',
}

for _, flag in ipairs(blacklistedSearchFlags) do
  table.insert(blacklistedReplaceFlags, flag)
end

return blacklistedReplaceFlags
