--- The persistency interface for transformer

-- NOTE:
--   Several functions take an ireferences parameter. The ireferences is a table
--   with a combination of instance numbers (as specified in TR-106 and generated by
--   Transformer) and instance names (pass through values). The ireferences table
--   should contain the instance references in reverse order.
--   So ireferences[1] refers to the deepest level in the tree.

-- NOTE:
--   All functions manipulating the database will throw an error if they
--   fail in unexpected ways.
--   If errors are reported they are errors that can be expected to happen.
--   (eg duplicate keys on insert)

local M = {}

local require, tostring, pairs, ipairs, setmetatable, type, next =
      require, tostring, pairs, ipairs, setmetatable, type, next
local format = string.format
local concat = table.concat

local db = require("transformer.persistency.db")
local logger = require("transformer.logger").new('DB')
local pathFinder = require("transformer.pathfinder")
local fault = require("transformer.fault")

local stripEndNoTrailingDot =
      pathFinder.stripEndNoTrailingDot
local isMultiInstance,            endsWithPassThroughPlaceholder =
      pathFinder.isMultiInstance, pathFinder.endsWithPassThroughPlaceholder

local Persistency={}

--- Create a database string representing the instance references.
-- @param #table ireferences A table containing the instance references in
--                           reverse order.
-- @return #string A string representation for the instance references that can
--                 be used by the database.
local function string_from_ireferences(ireferences)
  if ireferences then
    return concat(ireferences, '.')
  else
    return ""
  end
end

--- Transform a database instance references string to the corresponding
-- instance references table.
-- @param #string s The string representation for the instance references.
-- @return #table A table containing the instance references in reverse order.
local function ireferences_from_string(s)
  local ireferences = {}
  for f in s:gmatch("([^.]*).?") do
    -- the last match will be an empty string
    if f ~= "" then
      ireferences[#ireferences+1] = f
    end
  end
  return ireferences
end

--- Append an instance reference to a ireferences string
-- @param #string iref The ireferences as a database string.
-- @param #string instance The instance reference to add.
-- @return #string The correct database string that will result in the correct ireferences
--    table when converted later on.
local function string_append_instance(iref, instance)
  if #iref>0 then
    return instance.."."..iref
  end
  return instance
end

--- Get the DB entry corresponding to the given typepath ID and instance references.
-- @param #table db The database object.
-- @param #number tp_id The typepath ID of the object.
-- @param #string iref The instance references string for the object.
-- @return #table The actual database row if the object is found,
--    nil otherwise.
-- If the typepath is single instance it is added to the database if needed.
local function getObject(db, tp_id, iref)
  local obj = db:getObject(tp_id, iref)
  if obj==nil then
    -- the object does not exist in the database yet
    -- if the type path indicates single instance, we can add it
    -- for multi instance this is an error (handled by the caller)
    local tp_chunk = db:getTypePathChunkByID(tp_id)
    if tp_chunk.is_multi == 0 then
      -- This is a single instance, find the parent
      local parent
      if tp_chunk.parent == 0 then
        -- type path is the top level (eg Device.) so there is no
        -- parent
        parent = {}
      else
        parent = getObject(db, tp_chunk.parent, iref)
        -- if parent is nil here, this signals an error
        -- the parent could not be located.
      end
      if parent~=nil then
        -- we found a parent object, so we can insert the given
        -- type path in the database
        -- as it is single instance, it inherits the key of first
        -- multi-instance parent (if any)
        obj = db:insertObject(tp_id, iref, parent.key or "", parent.id)
      end
    end
  end
  return obj
end

--- Get the parent database object for a given multi instance typepath ID and given
-- instance references.
-- @param #table db The database object.
-- @param #number tp_id The database ID of the typepath, must be multi-instance.
-- @param #string iref The instance references as a string.
-- @return #table, #string The database object of the parent and the child part of the
--                         typepath or nil if not found.
local function getParentOfMulti(db, tp_id, iref)
  local tp_chunk = db:getTypePathChunkByID(tp_id)
  assert(tp_chunk, "typepath id needs to exist")
  assert(tp_chunk.is_multi == 1, "path must be multi instance")

  local child = tp_chunk.typepath_chunk
  local ppath_id = tp_chunk.parent
  local parent = getObject(db, ppath_id, iref)

  return parent, child
end

--- Helper function to add an entry to the database.
-- @param #table db The database object.
-- @param #string cpath The child portion of the type path.
-- @param #string iref_parent The instance references string of the parent object.
-- @param #number tp_id The database ID of the typepath of the object.
-- @param #string key The key of the object.
-- @param #number parent_db_id The database id of the parent object.
-- @param #boolean keyIsTable Indicates if the given key is a table or a string.
-- @return #string The generated instance reference. Throws an error if something goes wrong.
local function addInstance(db, cpath, iref_parent, tp_id, key, parent_db_id, keyIsTable)
  -- generate the new instance number
  logger:debug("addInstance: %s, %d, %d", cpath, tp_id, parent_db_id)
  local endsWithTransformed = (not endsWithPassThroughPlaceholder(cpath))
  local instance
  local actual_key = key
  if endsWithTransformed then
    instance = db:getCount(parent_db_id, tp_id)+1
    instance = tostring(instance) -- We want the instance reference to be a string.
  else
    if keyIsTable then
      instance = key[1]
      actual_key = key[2]
    else
      instance = key
    end
  end

  if instance then
    -- generate the instance references string for the object
    local refs = string_append_instance(iref_parent, instance)
    -- insert it in the db
    local obj, msg = db:insertObject(tp_id,
                                    refs,
                                    actual_key,
                                    parent_db_id)
    if obj==nil then
      local err_msg = format("database: %s, tp_id='%d', ireferences='%s', key='%s'", msg, tp_id, refs, actual_key)
      logger:error(err_msg)
      fault.InternalError(err_msg);
    end
    if endsWithTransformed then
      -- store the instance number in count
      -- we do it here just in case we are not in a transaction. The insert
      -- succeeded so we do not leave a hole in the numbering.
      db:setCount(parent_db_id, tp_id, instance)
    end
    return instance
  end
  -- No instance, throw error
  fault.InternalError("Persistency: no instance to add!");
end

--- Get the key of the given typepath ID and instance references.
-- @param #number tp_id The database ID of the full typepath of the object.
-- @param #table ireferences The table with all instance references.
-- @return #string The key stored in the database if it exists or nil.
function Persistency:getKey(tp_id, ireferences)
  local iref = string_from_ireferences(ireferences)
  local obj = self._db:getObject(tp_id, iref)
  if obj then
    return obj.key
  end
end

--- Get the ireferences of the given typepath ID and key.
-- @param #number tp_id The database ID of the full typepath of the object.
-- @param #string key The key of the object.
-- @return #table The ireferences table stored in the database if it exists or nil.
function Persistency:getIreferences(tp_id, key)
  local obj = self._db:getObjectByKey(tp_id, key)
  if obj then
    return ireferences_from_string(obj.ireferences)
  end
end

--- Add an entry to the database.
-- @param #number tp_id The database ID of the typepath of the object to add.
-- @param #table ireferences_parent The instance references of the parent object.
-- @param #string or #table key The key of the object.
-- @return #string The assigned instance reference or nil in case of error.
function Persistency:addKey(tp_id, ireferences_parent, key)
  local db = self._db
  local iref = string_from_ireferences(ireferences_parent)
  local parent, cpath = getParentOfMulti(db, tp_id, iref)
  assert(parent, "a parent does not exist")

  -- Check if the given key is a string or a table.
  local keysTuples = (type(key) == "table")

  return addInstance(db, cpath, iref, tp_id, key, parent.id, keysTuples)
end

--- Delete an entry from the database.
-- @param #number tp_id The database ID of the typepath of the object.
-- @param #table ireferences The instance references of the object.
-- @return nil
function Persistency:delKey(tp_id, ireferences)
  local iref = string_from_ireferences(ireferences)
  self._db:deleteObject(tp_id, iref)
end

local function query_keys_impl(db, tp_id, level)
  local keys = {}
  if level < 1 then
    return keys
  end
  -- We need to find the first level of multi-instance before we can iterate.
  local tp_chunk = db:getTypePathChunkByID(tp_id)
  while tp_chunk.is_multi ~= 1 and tp_chunk.parent ~= 0 do
    tp_chunk = db:getTypePathChunkByID(tp_chunk.parent)
  end
  if tp_chunk.parent == 0 then
    -- typepath is a root path or contains no multi-instance levels.
    return keys
  end
  -- tp_chunk now points to the lowest multi-instance level, populate keys
  -- with all entries of this level.
  local level_keys = db:getSiblings(tp_chunk.tp_id)
  if not level_keys or next(level_keys) == nil then
    -- There are no entries found on this level, no point in looking further.
    return keys
  end

  for i, row in ipairs(level_keys) do
    keys[i] = { key = {row.key}, nextparent = row.parent}
  end
  -- We found a level, decrease
  level = level - 1

  while level > 0 do
    -- We want more info, look for parents
    local parent_keys = db:getParents(tp_chunk.tp_id)
    if not parent_keys or #parent_keys == 0 then
      -- No parents found, no more multi-instance parents available.
      break
    end
    -- Parent entries found. Two possibilities:
    --    The parent typepath is single instance -> we need to look further
    --    The parent typepath is multi instance -> merge the keys
    local parent_tp_id = parent_keys[1].tp_id -- This should be the same for all parents.
    local parent_tp_chunk = db:getTypePathChunkByID(parent_tp_id)
    if parent_tp_chunk.parent == 0 then
      -- Reached the root.
      break
    end
    -- If the parent is multi instance, we need to append the parent keys.
    local append_keys = true
    if parent_tp_chunk.is_multi ~= 1 then
      -- Possibility 1: parent = single instance.
      -- Don't append the keys, just update the next parent keys.
      append_keys = false
    else
      -- Possibility 2
      level = level - 1
    end

    for _, row in ipairs(parent_keys) do
      -- Loop over the previously found keys and update and/or append.
      for _, found in ipairs(keys) do
        if found.nextparent == row.id then
          if append_keys then
            found.key[#found.key + 1] = row.key
          end
          -- Update the next parent key
          found.nextparent = row.parent
        end
      end
    end

    -- Level up
    tp_chunk = parent_tp_chunk
  end

  -- Only keep the key of every entry in the array
  for i, entry in pairs(keys) do
    keys[i] = entry.key
  end
  return keys
end

--- Query the database for the specified typepath ID and retrieve all the keys, parent keys, ... up to
-- the given level.
-- @param #number tp_id The database ID of the typepath to query.
-- @param #number level How many of levels we wish to query.
-- @return #table Returns an array of arrays with the key, parent key, ... If there are no
--                keys then an empty array is returned.
function Persistency:query_keys(tp_id, level)
  if type(level) ~= "number" then
    level = 1
  end
  local ok, result = pcall(query_keys_impl, self._db, tp_id, level)
  if not ok then
    -- log error and return empty table.
    logger:error(result)
    return {}
  end
  return result
end

-- the actual implementation of the sync
local function sync_impl(db, tp_id, keys, ireferences_parent)
  local keymap = {}
  local iref = string_from_ireferences(ireferences_parent)

  local parent, child = getParentOfMulti(db, tp_id, iref)
  assert(parent, "a parent does not exist")

  -- retrieve the objects currently in the database
  local db_objects = db:getChildren(parent.id, tp_id)

  -- Check if the given keys are strings or tables.
  local keysTuples = false
  if keys and type(keys[1]) == "table" then
    keysTuples = true
  end

  -- build the result keymap by making sure all the given keys are in
  -- the database.
  for _, key in ipairs(keys) do
    local actual_key = key
    if keysTuples then
      actual_key = key[2]
    end
    local index = db_objects[actual_key]
    local instance
    if index then
      local obj = db_objects[index]
      -- the key is present in the database
      -- remove it from the db_object table to mark it as processed
      -- and present.
      db_objects[index] = nil
      db_objects[actual_key] = nil

      -- extract the instance reference at this level
      local inst = ireferences_from_string(obj.ireferences)
      instance = inst[1]
    else
      -- addInstance will either succeed or throw an error.
      instance = addInstance(db, child, iref, tp_id, key, parent.id, keysTuples)
    end
    if instance then
      keymap[instance] = actual_key
    end
  end

  -- whatever objects remain in the database list, do no longer exist
  -- in reality.
  -- remove them from the database.
  for _, obj in pairs(db_objects) do
    if type(obj)=='table' then
      db:deleteObject(obj.tp_id, obj.ireferences)
    end
  end

  return keymap
end

--- Synchronize the database for the given typepath ID.
-- @param #number tp_id The database ID of the typepath to update (must be multi-instance).
-- @param #table keys A list of keys for all lower layer objects.
-- @param #table ireferences_parent The instance reference array for the parent object (this could
--                       be empty)
-- @return #table A mapping of all instance numbers on this level to the
--                given keys.
-- The database is updated to match this state.
-- in case of a constraint violation the function returns nil and the database
-- is not changed.
function Persistency:sync(tp_id, keys, ireferences_parent)
  local db = self._db
  local result

  -- wrap the sync_impl call in a transaction to handle the error case.
  -- We don't know if this is the outer transaction, so create an inner one
  -- to be safe.
  local savepoint = db:startTransaction(false)
  local ok
  ok, result = pcall(sync_impl, db, tp_id, keys, ireferences_parent)
  local commit = ok and result
  if commit then
    db:commitTransaction(savepoint)
  else
    db:rollbackTransaction(savepoint)
  end
  if not ok then
    -- propagate error
    error(result)
  end
  return result
end

--- Split the given typepath in typepath chunks.
-- @param #string typepath The typepath that needs to be chunked. This must NOT contain a parameter name.
-- @return #table The given typepath in chunks in reversed order (eg. the chunk at index
--                1 is the last chunk of the typepath). Chunks are either 'Single.' or 'Multi.{i}.'.
local function create_tp_chunks(typepath)
  local tp_chunks = {}
  local first, chunk = stripEndNoTrailingDot(typepath)
  local multi
  while chunk and chunk~="" do
    typepath = first
    if isMultiInstance(chunk) then
      multi = chunk .. "."
    else
      chunk = chunk.."."
      if multi then
        chunk = chunk..multi
      end
      tp_chunks[#tp_chunks + 1] = {chunk=chunk, multi=(multi~=nil)}
      multi = nil
    end
    first, chunk = stripEndNoTrailingDot(typepath)
  end
  return tp_chunks
end

--- Add a typepath to database.
-- @param #string typepath The typepath that needs to be added.
-- @return #number The database ID of the typepath.
function Persistency:addTypePath(typepath)
  return self._db:insertTypePath(create_tp_chunks(typepath))
end

function Persistency:close()
  self._db:close()
  self._db = nil
end

--- Start a transaction on database level.
-- NOTE: This should be followed by either a call to commit or
--       a call to revert. Calling this function again before
--       commit or revert has been called will result in an error.
function Persistency:startTransaction()
  self._db:startTransaction(true)
end

--- Commit a transaction on database level.
-- NOTE: This should only be called when a transaction is in progress,
--       otherwise this function will raise an error. Any sub-transactions
--       will also be committed.
function Persistency:commitTransaction()
  self._db:commitTransaction()
end

--- Revert a transaction on database level.
-- NOTE: This should only be called when a transaction is in progress,
--       otherwise this function will raise an error. Any sub-transactions
--       will also be reverted.
function Persistency:revertTransaction()
  self._db:rollbackTransaction()
end

Persistency.__index = Persistency
function M.new(dbpath, dbname)
  local p={
    _db = db.new(dbpath, dbname);
  }

  return setmetatable(p, Persistency)
end

return M
