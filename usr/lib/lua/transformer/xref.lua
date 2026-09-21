
local require = require
local insert, remove = table.insert, table.remove
local pairs, ipairs, string, type, error = pairs, ipairs, string, type, error

local M = {}

local fault = require("transformer.fault")
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

  -- map all entries for the current mapping with irefs_parent and keys
  local next_index = index + 1
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
  local path
  -- if key is not valid, just return nil
  if type(key) ~= "string" then
    return
  end

  -- build the maplist.
  -- This is needed as we need to query the database with a multi-instance
  -- typepath. Leaf single instance objects are not stored in the DB.
  local maplist = {}
  local mapping = store:get_mapping_exact(typepath)
  -- fail if the mapping was not found
  if not mapping then
    return
  end
  while mapping do
    if store:isMultiInstanceMapping(mapping) then
      insert(maplist, 1, mapping)
    end
    mapping = store:parent(mapping)
  end

  -- if the list happens to be empty, there is no work to do
  -- we check for it, but it would be a silly call as the return value
  -- in this case is just typepath with the dot removed
  if #maplist>0 then
    -- get the typepath of the longest multi instance subpath from typepath
    local lastMI = maplist[#maplist].objectType.name
    -- try to find the given object in the DB
    local inumbers = store.persistency:getIreferences(lastMI, key)

    if not inumbers and not no_sync then
      -- the object was not found in the DB, try to update the DB.
      update(store, maplist, 1, {}, {})
      -- Try to retrieve the object again.
      inumbers = store.persistency:getIreferences(lastMI, key)
    end

    if inumbers then
      -- generate full path
      path = typePathToObjPath(typepath, inumbers, {})
    end
  else
    -- the silly case
    path = typepath
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
      error( string.format("%s refers to an unexpected type", objectpath))
    end
  end

  -- if the given mapping is not a multi instance one, move up in the
  -- parent chain, up to the first parent.
  while mapping and not store:isMultiInstanceMapping(mapping) do
    mapping = store:parent(mapping)
  end

  if not mapping then
    -- silly case, this is single instance all the way up
    -- there is no key
    return '', tp
  end

  return store.persistency:getKey(mapping.objectType.name, inumbers), tp
end

return M
