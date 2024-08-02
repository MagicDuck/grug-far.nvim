-- ripgrep engine API

---@class GrugFarEngine
---@field search fun(params: string): string

local M = {}

-- TODO (sbadragan): should be an object
--- performs search
---@param params string
---@return string
function M.search(params)
  return 'searching' .. params
end

---@type GrugFarEngine
local e
e = M
P(e.search('foo'))

---@type GrugFarEngine
local C = {
  searchx = function(str)
    return 'hi' .. str
  end,
}

local bob
bob = C

P(bob.search('sdf'))

---@class A
---@field search fun(params: string): string
local A = {}

---@class B
---@field flop fun(params: string): string
local B = {}

---@alias E A | B

---@param type string
---@return E
local function getEngine(type)
  if type == 'rg' then
    return A
  else
    return B
  end
end

local eng = getEngine('rg')
eng.search('i')

local C = {}
function C.searchx(str)
  return 'hi' .. str
end

local rob
---@cast C GrugFarEngine
rob = C

P(rob.search('sdf'))

return M
