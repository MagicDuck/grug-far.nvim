---@alias Region (Range4|Range6|TSNode)[]
---@alias LangRegions table<string, Region[]>
---@alias FileResults table<string, {ft: string?, lines: grug.far.ResultLine[]}>

---@class grug.far.ResultLine
---@field row number row in the result buffer for this line
---@field col number col in the result buffer for this line
---@field end_col number end col in the result buffer for this line
---@field lnum number line number in the file

local M = {}

M.cache = {} ---@type table<number, table<string,{parser: vim.treesitter.LanguageTree, highlighter:vim.treesitter.highlighter, enabled:boolean, regionsId?: string, regions?: Region[]}>>
local ns = vim.api.nvim_create_namespace('grug.treesitter')

local TSHighlighter = vim.treesitter.highlighter

local function wrap(name, cb)
  return function(firstArg, win, buf, ...)
    if not M.cache[buf] then
      return false
    end

    local callback = TSHighlighter[name] --[[@as fun()]]
    for _, hl in pairs(M.cache[buf] or {}) do
      if hl.enabled then
        if cb then
          cb(hl.highlighter, buf, ...)
        end
        TSHighlighter.active[buf] = hl.highlighter
        pcall(callback, firstArg, win, buf, ...)
      end
    end
    TSHighlighter.active[buf] = nil
  end
end

M.did_setup = false
function M.setup()
  if M.did_setup then
    return
  end
  M.did_setup = true
  local has_nvim12 = vim.fn.has('nvim-0.12.0') == 1

  local on_range = wrap('_on_range')
  local on_line = has_nvim12
      and function(_, win, buf, row)
        return on_range(_, win, buf, row, 0, row + 1, 0)
      end
    or wrap('_on_line')

  -- https://github.com/neovim/neovim/issues/36503
  local on_win_pre = has_nvim12
      and function(h, buf, topline, botline)
        if h.parsing then
          return
        end
        h.parsing = nil
          == h.tree:parse({ topline, botline + 1 }, function(_, trees)
            if trees and h.parsing then
              h.parsing = false
              vim.api.nvim__redraw({ buf = buf, valid = false, flush = false })
            end
          end)
      end
    or nil

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = wrap('_on_win', on_win_pre),
    on_line = on_line,
  })
end

---@param buf number
---@param skipRegionsWithIds? boolean
function M.clear(buf, skipRegionsWithIds)
  for cache_key, hl in pairs(M.cache[buf] or {}) do
    if not (skipRegionsWithIds and hl.regionsId) then
      hl.highlighter:destroy()
      hl.parser:destroy()
      M.cache[buf][cache_key] = nil
    end
  end
  if M.cache[buf] and vim.tbl_isempty(M.cache[buf]) then
    M.cache[buf] = nil
  end
end

---@param buf number
---@param regions LangRegions
---@param regionsId string?
function M.attach(buf, regions, regionsId)
  M.setup()
  M.cache[buf] = M.cache[buf] or {}

  if not regionsId then
    -- stop caring about older highlighted regions, for perf sake
    for cacheKey in pairs(M.cache[buf]) do
      local entry = M.cache[buf][cacheKey]
      -- note: entries with a region id are always highlighted
      if not entry.regionsId then
        entry.enabled = regions[cacheKey] ~= nil
      end
    end
  end

  for lang in pairs(regions) do
    M._attach_lang(buf, lang, regions[lang], regionsId)
  end
end

---@param buf number
---@param lang string
---@param regions Region[]
---@param regionsId string?
function M._attach_lang(buf, lang, regions, regionsId)
  lang = lang == 'markdown' and 'markdown_inline' or lang

  M.cache[buf] = M.cache[buf] or {}

  local cacheKey = regionsId and lang .. '__' .. regionsId or lang
  local entry = M.cache[buf][cacheKey]

  if regionsId and entry and entry.regions and vim.deep_equal(regions[lang], entry.regions) then
    -- trying to highlight same regions, nothing to do
    return
  end

  if not entry then
    local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
    if not ok or not parser then
      return
    end
    ---@diagnostic disable-next-line: invisible
    parser:set_included_regions(regions)
    M.cache[buf][cacheKey] = {
      parser = parser,
      ---@diagnostic disable-next-line: invisible
      highlighter = TSHighlighter.new(parser),
      regionsId = regionsId,
    }
    entry = M.cache[buf][cacheKey]
  end
  entry.enabled = true
  ---@diagnostic disable-next-line: invisible
  entry.parser:set_included_regions(regions)
  if regionsId then
    entry.regions = regions
  end
end

return M
