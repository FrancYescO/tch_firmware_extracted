
local require = require
local insert, remove = table.insert, table.remove
local pairs, ipairs, string, type, error, unpack = pairs, ipairs, string, type, error, unpack

local M = {}

local fault = require("transformer.fault")
local pathFinder = require("transformer.pathfinder")

local typePathToObjPath,            objectPathToTypepath =
      pathFinder.typePathToObjPath, pathFinder.objectPathToTypepath

--- Function to collect all mappings that are above the given mapping and the mapping itself.
-- @param #table store The typestore table.
-- @param #table mapping The mapping for which we want all parent mappings.
-- @return #table A table containing all the parent mappings of the given mapping,
--                including the given mapping as the final element.
local function collectParentMappings(store, mapping)
  local last_multi
  local maplist = {}
  -- build the maplist.
  while mapping do
    if not last_multi and store:isMultiInstanceMapping(mapping) then
      -- Keep track of the lowest multi instance
      last_multi = mapping
    end
    -- Insert all mappings
    insert(maplist, 1, mapping)
    mapping = store:parent(mapping)
  end
  return maplist, last_multi
end

--- Function to collect all keys that correspond to the given ireferences.
-- @param #table store The typestore table.
-- @param #table mappings The mappings to which the ireferences correspond.
-- @return #table A table containing all the keys corresponding to the given ireferences.
local function collectParentKeys(store, mappings, ireferences)
  local persist = store.persistency
  local keys = {}
  local key, irefs
  -- mappings are ordered from root to bottom, eg.mappings[1] = root mapping.
  for dotlevel, mapping in ipairs(mappings) do
    if store:isMultiInstanceMapping(mapping) then
      irefs = {unpack(ireferences,1,dotlevel)}
      key = persist:getKey(mapping.tp_id, irefs)
      insert(keys, 1, key)
    end
  end
  return keys
end

--- recursively update the DB
-- @param store the mapping store to use
-- @param maplist an array of mappings (see note)
-- @param index index into maplist to select the current mapping to update
-- @param irefs_parent the instance references for the parent object
-- @param keys the keys for the parent object
-- @returns nothing
-- The maplist is build such that it only contains multi instance types.
-- Each entry is a child (or grand child, ...) of the previous.
-- When initially called, index should be 1 and irefs_parents and keys should be
-- empty tables.
local function update(store, maplist, index, irefs_parent, keys)
  local mapping = maplist[index]
  if not mapping then
    -- There is nothing more to map, we're done
    return
  end

  local next_index = index + 1
  if store:isMultiInstanceMapping(mapping) then
    -- map all entries for the current mapping with irefs_parent and keys
    -- synchronize will either succeed or throw an error
    local iks = store:synchronize(mapping, keys, irefs_parent)
    -- for all entries, map their children
    for inb, key in pairs(iks) do
      insert(irefs_parent, 1, inb)
      insert(keys, 1, key)
      update(store, maplist, next_index, irefs_parent, keys)
      remove(irefs_parent, 1)
      remove(keys, 1)
    end
  elseif store:isOptionalSingleInstanceMapping(mapping) then
    if store:exists(mapping, keys) then
      update(store, maplist, next_index, irefs_parent, keys)
    end
  else
    -- Single instance mapping
    update(store, maplist, next_index, irefs_parent, keys)
  end
end

local empty = {}

--- resolve a given typepath and key to a tree reference
-- @param store the mapping store to use
-- @param typepath the name for the mapping
-- @param key the key
-- @param no_sync Boolean indicating whether to synchronize with the mapping(s)
--                when resolving fails.
-- @return a path in the tree or nil if it does not exist.
-- To be in-line with TR-106 the returned path will not have a terminating
-- dot.
--
-- This function has no way of checking whether the given key exists (eg on UCI)
-- or not. It simply assumes it is a valid key. Therefore the check for the
-- validity of the key must be made before calling resolve.
-- Failure to do so results in superfluous processing or a logically incorrect
-- result.
function M.resolve(store, typepath, key, no_sync)
  local inumbers, path, last_multi_tpid
  -- if key is not valid, just return nil
  if type(key) ~= "string" then
    return
  end

  local mapping = store:get_mapping_exact(typepath)
  -- fail if the mapping was not found
  if not mapping then
    return
  end
  -- build the maplist.
  -- This is needed as we need to query the database with a multi-instance
  -- typepath. Leaf single instance objects are not stored in the DB.
  local maplist, last_multi = collectParentMappings(store, mapping)
  if last_multi then
    last_multi_tpid = last_multi.tp_id
    -- try to find the given object in the DB
    inumbers = store.persistency:getIreferences(last_multi_tpid, key)
  else
    -- No multi-instance mappings in the path. Check for optional single instance.
    for _, map in ipairs(maplist) do
      if store:isOptionalSingleInstanceMapping(map) then
        local exists = store:exists(map, empty)
        if not exists then
          return
        end
      end
    end
    path = typepath
  end

  if not path and not inumbers and no_sync then
    -- Nothing found in the database and not allowed to sync: done.
    return
  elseif not path and not inumbers then
    -- typepath contains at least one multi instance and no DB hit yet: sync.
    update(store, maplist, 1, {}, {})
    -- Try to retrieve the object again.
    inumbers = store.persistency:getIreferences(last_multi_tpid, key)
  end

  if inumbers then
    -- We have a hit in the DB, check if there are optional single instance mappings
    -- below the last multi instance mapping in the path.
    local dotlevel = last_multi.dotlevel + 1
    local checkkeys
    while maplist[dotlevel] do
      if store:isOptionalSingleInstanceMapping(maplist[dotlevel]) then
        if not checkkeys then
          -- There is an optional single instance mapping, we need to get all keys of the
          -- last multi instance object so we can pass them to the option single instance entries function.
          checkkeys = collectParentKeys(store, maplist, inumbers)
        end
        if checkkeys and not store:exists(maplist[dotlevel], checkkeys) then
          return
        end
      end
      dotlevel = dotlevel + 1
    end
    -- generate full path
    path = typePathToObjPath(typepath, inumbers)
  end

  if path then
    -- remove the ending dot
    return (path:gsub("%.$", ""))
  end
end

--- Convert an object path to its key and typepath
-- @param store the typestore to use
-- @param objectpath the object path to convert
-- @param typepath... an optional number of valid typepaths. If given the
--   objectpath must refer to one of the typepaths to get a valid conversion.
-- @returns key, typepath with the found key and typepath, empty strings if
--   objectpath is nil or empty.
--   returns nil if not found.
--
-- In case the given objectpath is invalid or does not match any of
-- the given valid typepaths an error is raised.
function M.tokey(store, objectpath, typepath, ...)
  local validpaths
  if typepath then
    validpaths = {typepath, ...}
  end

  --if no objectpath given, just return an empty string
  if (not objectpath) or (objectpath=='') or (type(objectpath)~="string")then
    return '', ''
  end

  -- an objectpath must end in a dot, but an xref in TR-106 does not
  -- Add the missing dot now
  if not objectpath:find("%.$") then
    objectpath = objectpath..'.'
  end

  -- convert given objectpath to its typepath and inumbers
  local tp, inumbers = objectPathToTypepath(objectpath)

  -- the found typepath (tp) must exist
  local mapping = store:get_mapping_exact(tp)
  if not mapping then
    error(string.format("%s does not refer to an existing type", objectpath))
  end

  -- if a list of valid typepath were given, check if the found one (tp)
  -- is one of them
  if validpaths then
    local found = false
    for _, p in ipairs(validpaths) do
      if tp==p then
        found = true
        break
      end
    end
    if not found then
      -- unfortunately it was not in the list of valid paths
      error(string.format("%s refers to an unexpected type", objectpath))
    end
  end

  -- Collect all parent mappings
  local maplist, last_multi = collectParentMappings(store, mapping)

  if not last_multi then
    -- silly case, this is single instance all the way up
    -- there is no key
    return '', tp
  end

  local last_multi_tpid = last_multi.tp_id
  local key = store.persistency:getKey(last_multi_tpid, inumbers)
  if not key then
    -- sync
    update(store, maplist, 1, {}, {})
    key = store.persistency:getKey(last_multi_tpid, inumbers)
  end
  -- if key found, check for potential optional single instance below last multi.
  if key then
    local dotlevel = last_multi.dotlevel + 1
    local checkkeys
    while maplist[dotlevel] do
      if store:isOptionalSingleInstanceMapping(maplist[dotlevel]) then
        if not checkkeys then
          checkkeys = collectParentKeys(store, maplist, inumbers)
        end
        if checkkeys and not store:exists(maplist[dotlevel], checkkeys) then
          -- Not found
          return
        end
      end
      dotlevel = dotlevel + 1
    end
  end
  return key, tp
end

return M
