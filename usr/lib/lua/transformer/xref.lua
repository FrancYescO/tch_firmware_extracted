--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local insert, remove = table.insert, table.remove
local pairs, ipairs, string, type, error, pcall =
      pairs, ipairs, string, type, error, pcall

local M = {}

local pathFinder = require("transformer.pathfinder")

local typePathToObjPath,            objectPathToTypepath =
      pathFinder.typePathToObjPath, pathFinder.objectPathToTypepath

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
    for _, inb in ipairs(iks) do
      local key = iks[inb]
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

-- Actual resolve implementation. This function should be pcall()'d.
local function resolve_impl(store, typepath, key, no_sync)
  local inumbers, path, last_multi_tpid
  -- if key is not valid, just return nil
  if type(key) ~= "string" then
    return
  end

  -- build the maplist.
  -- This is needed as we need to query the database with a multi-instance
  -- typepath. Leaf single instance objects are not stored in the DB.
  local maplist, last_multi = store:collectMappings(typepath)
  -- If the last entry in maplist isn't the given typepath that means
  -- the typepath lacked the MI identifier (e.g. {i}). We treat this
  -- as failure to resolve.
  if maplist[#maplist].objectType.name ~= typepath then
    return
  end
  if last_multi then
    last_multi_tpid = last_multi.tp_id
    -- try to find the given object in the DB
    inumbers = store.persistency:getIreferences(last_multi_tpid, key)
  else
    -- No multi-instance mappings in the path. Check for optional single instance.
    -- The getkeys() function throws an error if one doesn't exist.
    store:getkeys(maplist, empty, empty, no_sync)
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
    -- Check if there are optional single instance mappings
    -- below the last multi instance mapping in the path.
    store:getkeys(maplist, inumbers, empty, no_sync)
    -- generate full path
    path = typePathToObjPath(typepath, inumbers)
  end

  if path then
    -- remove the ending dot
    return (path:gsub("%.$", ""))
  end
end

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
  local rc, path = pcall(resolve_impl, store, typepath, key, no_sync)
  if not rc then
    return nil
  end
  return path
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

  -- if no objectpath given, just return an empty string
  if (not objectpath) or (objectpath == "") or (type(objectpath) ~= "string") then
    return "", ""
  end

  -- an objectpath must end in a dot, but an xref in TR-106 does not
  -- Add the missing dot now
  if not objectpath:find("%.$") then
    objectpath = objectpath .. "."
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
      if tp == p then
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
  local maplist, last_multi = store:collectMappings(tp)
  if not last_multi then
    -- silly case, this is single instance all the way up
    -- there is no key
    return "", tp
  end

  -- Retrieve all keys from DB and check any optional single instances exist.
  local key
  local rc, keys = pcall(store.getkeys, store, maplist, inumbers, empty, true)
  if rc then
    -- Everything checked out OK; our key is the first one in the list.
    -- (keys are returned in reverse order)
    key = keys[1]
  else
    -- Some instance could not be found; try again but allow to sync.
    rc, keys = pcall(store.getkeys, store, maplist, inumbers, empty)
    if rc then
      key = keys[1]
    end
  end
  if key then
    return key, tp
  end
  return key
end

return M
