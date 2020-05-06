-- This mapper will implement a cache mapper.
-- This means that the values and the objects are not linked to any backend.

-- WARNING: This mapper is no longer supported since 19/11/2013. It will be removed
-- during the next refactoring. Do NOT use!
-- WARNING: not usable with more than one level of multi instanceness

local M = {}

local function get_cache(mapping, key)
    local cache = mapping[M]
    if nil == cache then
        cache = {}
        mapping[M] = cache
    end
    if mapping.objectType.maxEntries > 1 then
        cache = cache[tonumber(key)]
    end
    return cache
end

local function get(mapping, paramname, key)
    return get_cache(mapping, key)[paramname] or mapping.objectType.parameters[paramname].default or ""
end

local function set(mapping, paramname, paramvalue, key)
    local entry = get_cache(mapping, key, true)
    entry[paramname] = paramvalue
end

local function entries(mapping)
    local cache = mapping[M]
    local keys = {}
    if nil ~= cache then
        for i in pairs(cache) do
            keys[#keys + 1] = tostring(i)
        end
    end
    return keys
end

local function delete(mapping, parentkey)
  local cache = mapping[M]
  if nil == cache then
    cache = {}
    mapping[M] = cache
  end
  cache[parentkey] = nil
  return true
end

local function add(mapping)
  local cache = mapping[M]
  if nil == cache then
    cache = {}
    mapping[M] = cache
  end
  local index = #cache + 1
  cache[index] = {}
  return tostring(index)
end

--- Connect the cached mapper with its mapping
-- @param mapping the object mapping
-- @param initial_entries [optional] Array where each entry is a table with param/value pairs.
--   Use an empty table to use the default parameter values as defined in your type definition.
function M.connect(mapping, initial_entries)
    mapping.get = get
    mapping.set = set
    local objtype = mapping.objectType
    if objtype.maxEntries > 1 then
        mapping.entries = entries
        mapping.add = add
        mapping.delete = delete
        mapping[M] = initial_entries
    end
end

return M
