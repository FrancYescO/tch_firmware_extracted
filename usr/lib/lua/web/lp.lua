----------------------------------------------------------------------------
-- Lua Pages Template Processor.
----------------------------------------------------------------------------

local ngx = ngx
local error, loadstring, ipairs =
      error, loadstring, ipairs
local find, format, gsub, sub = string.find, string.format, string.gsub, string.sub
local concat, tinsert, tremove = table.concat, table.insert, table.remove
local open = io.open

----------------------------------------------------------------------------
-- functions to do output ('outfunc' expects string or number, 'printfunc'
-- does tostring() so can process anything)
-- TODO: docs say that ngx.print() and ngx.say() are rather expensive. Perhaps
--       we should rewrite the translation of the template to buffer data in
--       a Lua table and only output at the end of a %> block.
local outfunc = "ngx.print"
local printfunc = "ngx.print"
-- the name of the directory from which files can be include()'ed
-- !! should be outside of the document root for security reasons !!
local includepath

local function setpath(path)
  includepath = path
end

----------------------------------------------------------------------------
-- Builds a piece of Lua code which outputs the (part of the) given string.
-- @param s String.
-- @param i Number with the initial position in the string.
-- @param f Number with the final position in the string (default == -1).
-- @return String with the corresponding Lua code which outputs the part of
--    the string.
-- @scope internal
----------------------------------------------------------------------------
local function out(s, i, f)
    s = sub(s, i, f or -1)
    if s == "" then return s end
    -- we could use `%q' here, but this way we have better control
    s = gsub(s, "([\\\n\'])", "\\%1")
    -- substitute '\r' by '\'+'r' and let `loadstring' reconstruct it
    s = gsub(s, "\r", "\\r")
    return format(" %s('%s'); ", outfunc, s)
end

----------------------------------------------------------------------------
-- Translate the template to Lua code.
-- @param s String to translate.
-- @return String with translated code.
-- @scope internal
----------------------------------------------------------------------------
local function translate(s)
  local res = {}

  local start = 1   -- start of untranslated part in `s'

  while true do
    local ip, fp, exp, code = find(s, "<%%[ \t]*(=?)(.-)%%>", start)
    if not ip then
      break
    end
    tinsert(res, out(s, start, ip-1))
    if exp == "=" then   -- expression?
      tinsert(res, format(" %s(%s);", printfunc, code))
    else  -- command
      tinsert(res, format(" %s ", code))
    end
    start = fp + 1
  end
  tinsert(res, out(s, start))
  return concat(res)
end


----------------------------------------------------------------------------
-- Internal compilation cache.
local cache = {}
local max_cache_size = 20

----------------------------------------------------------------------------
-- Set the size of the template cache.
-- @param size Number of entries (>= 0) to keep in the cache.
----------------------------------------------------------------------------
local function setcachesize(size)
  if size < 0 then
    error("cache size must be >= 0", 2)
  end
  -- if we're shrinking then throw out any excess elements
  if size < max_cache_size and #cache > size then
    for i = size + 1, #cache do
      cache[i] = nil
    end
  end
  max_cache_size = size
end

----------------------------------------------------------------------------
-- Flush the template cache.
----------------------------------------------------------------------------
local function flush()
  cache = {}
end

----------------------------------------------------------------------------
-- Translates a template into a Lua function.
-- Does NOT execute the resulting function.
-- @param string String with the template to be translated.
-- @param chunkname String with the name of the chunk, for debugging purposes.
-- @return Function with the resulting translation.
-- @scope internal
----------------------------------------------------------------------------
local function compile (string, chunkname)
  local translated_string = translate(string)
  local f, err = loadstring(translated_string, chunkname)

  if not f then
    error(err, 0)
  end

  return f
end

----------------------------------------------------------------------------
-- Translates a template in a given file.
-- The translation creates a Lua function which will be executed. Reuses a
-- cached translation if available.
-- @param filename String with the name of the file containing the template.
-- @param chunkname String to be used as chunkname when loading the file.
-- @return the translated code
----------------------------------------------------------------------------
local function load(filename, chunkname)
  chunkname = chunkname or filename
  -- Check if the file is present in the compilation cache
  local entry, position = nil, nil
  for k,v in ipairs(cache) do
    if v.filename == filename then
      entry = v
      position = k
      break
    end
  end

  if entry == nil then
    -- read the whole contents of the file
    local fh = open(filename)
    if not fh then
      ngx.exit(404)
    end
    local src = fh:read("*a")
    fh:close()

    -- translates the file into a function and cache it

    local content = compile(src, chunkname)
    entry = { filename = filename,
              content = content }

    if max_cache_size > 0 then
      -- there is a cache we can insert to
      -- If cache is full clear oldest entry
      if #cache >= max_cache_size then
        tremove(cache)
      end

      -- Insert new entry on position one
      tinsert(cache, 1, entry)
    end
  else
    -- entry already existed (so there is a cache), move it to pos 1 of table
    if position ~= 1 then
      entry = tremove(cache, position)
      tinsert(cache, 1, entry)
    end
  end

  return entry and entry.content 
end

----------------------------------------------------------------------------
-- Includes the given file at the location in the current document where
-- it is called.
-- @param filename The name of the file to be included relative to the
--                 include directory.
----------------------------------------------------------------------------
local function include (filename)
  local content = load(includepath .. filename, filename)
  -- include the specified filename, use the function environment
  -- of the function specifying the include.
  setfenv(content,getfenv(2))
  content()
end


local M = {
  setpath = setpath,
  setcachesize = setcachesize,
  flush = flush,
  load = load,
  include = include,
  translate = translate,
}
return M
