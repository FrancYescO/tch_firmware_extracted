local format,        gmatch,        find =
      string.format, string.gmatch, string.find
local insert, concat = table.insert, table.concat
local floor = math.floor
local error, unpack, require, setmetatable, assert, ipairs =
      error, unpack, require, setmetatable, assert, ipairs
local pcall = pcall
local fault = require("transformer.fault")
local nav = require("transformer.navigation")
local alias = require("transformer.alias")
local pathFinder = require("transformer.pathfinder")
local logger = require("transformer.logger")
local xpcall = require("tch.xpcall")
local traceback = debug.traceback

local stripEnd,            transformer_placeholder,            passthrough_placeholder =
      pathFinder.stripEnd, pathFinder.transformer_placeholder, pathFinder.passthrough_placeholder

-- Methods available on a store.
local TypeStore = {}
TypeStore.__index = TypeStore

--- A binary search on a table for a value
-- If the value is not found, return the position where the value
-- is expected.
-- @param t the table/array to search in (without holes)
-- @param v the value to search for
-- @return the index of the matching entry if found
--      or false, the index where the entry is supposed to exist
local function bin_search(mappings, v)
  local first, last = 1, #mappings
  while first <= last do
    local mid = floor((first + last)/2)
    local compval = mappings[mid].objectType.name
    if v == compval then
      return mid
    elseif v < compval then
      last = mid - 1
    else
      first = mid + 1
    end
  end
  return false, first
end

local transformer_pattern = transformer_placeholder.."%."
local passthrough_pattern = passthrough_placeholder.."%."

-- Calculate the tree depth of the given typepath.
-- This is done by counting the dots in the path but
-- a multi instance type only counts for 1 despite
-- having two dots (".{i}." or ".@.")
local function calculate_dotlevel(typepath)
  local dots = 0
  local is = 0
  for dot in gmatch(typepath, "%.") do
    dots = dots + 1
  end
  for i in gmatch(typepath, transformer_pattern) do
    is = is + 1
  end
  for i in gmatch(typepath, passthrough_pattern) do
    is = is + 1
  end
  return dots - is
end

--- Add the given mapping to the store.
-- @param mapping The mapping to add.
-- @return Nothing but raises an error if something is wrong
--         with the mapping (e.g. it already exists).
function TypeStore:add_mapping(mapping)
  local typepath = mapping.objectType.name
  local found, index = bin_search(self.mappings, typepath)
  if found then
    error(format("'%s' is already registered!", typepath))
  end
  mapping.dotlevel = calculate_dotlevel(typepath)
  mapping.tp_id = self.persistency:addTypePath(typepath)

  insert(self.mappings, index, mapping)
end

--- Retrieve the mapping belonging to the given typepath. The given typepath
-- needs to match exactly or nothing will be returned.
-- @param #string typepath The full typepath whose mapping to retrieve.
-- @return #table The mapping if found.
-- @return #nil If nothing was found.
function TypeStore:get_mapping_exact(typepath)
  local index = bin_search(self.mappings, typepath)
  if not index then
    return nil
  end
  return self.mappings[index]
end

local transformer_ending = transformer_placeholder.."."
local passthrough_ending = passthrough_placeholder.."."

--- Retrieve the mapping belonging to the given typepath. The given
-- typepath can be incomplete with regards to the possible ending
-- placeholder. This function will iterate over all possibilities.
-- @param #string typepath The (possibly incomplete) typepath whose mapping to retrieve.
-- @return #table The mapping if found.
-- @return #nil If nothing was found.
function TypeStore:get_mapping_incomplete(typepath)
  local mapping = self:get_mapping_exact(typepath)
  if not mapping then
    mapping = self:get_mapping_exact(typepath..transformer_ending)
  end
  if not mapping then
    mapping = self:get_mapping_exact(typepath..passthrough_ending)
  end
  return mapping
end

--- Iterator function for all direct children of a type path.
-- @param it_state The state passed to each iteration of the iterator.
-- @return The mapping of the next direct child of the type path defined in the iterator state
--         is returned if possible, nil otherwise.
local function objtype_child_it(it_state)
  local index = it_state.index + 1
  local dotlevel = it_state.dotlevel + 1
  local mappings = it_state.store.mappings
  local next_child = mappings[index]
  while next_child and find(next_child.objectType.name, it_state.typepath, 1, true) == 1 do
    if next_child.dotlevel == dotlevel then
      it_state.index = index
      return next_child
    end
    index = index + 1
    next_child = mappings[index]
  end
  return nil
end

--- Creates an iterator that will return all the direct
-- children of the given mapping.
-- @param mapping The mapping whose children you want.
-- @return Iterator (and iterator state) that will return the
--         next child every time it is called.
function TypeStore:children(mapping)
  local typepath = mapping.objectType.name
  local index = bin_search(self.mappings, typepath)
  assert(index)
  local it_state = { store = self, dotlevel = mapping.dotlevel, typepath = typepath, index = index }
  return objtype_child_it, it_state
end

--- Checks if the given mapping is a multi-instance mapping or not.
-- @param #table mapping The mapping we need to check
-- @return #boolean True if the given mapping is multi-instance (indicated by
--                  maxEntries being larger than one), false otherwise.
function TypeStore:isMultiInstanceMapping(mapping)
  return mapping.objectType.maxEntries>1
end

--- Checks if the given mapping is an optional single-instance mapping or not.
-- @param #table mapping The mapping we need to check
-- @return #boolean True if the given mapping is optional single-instance (indicated by
--                  minEntries being zero and maxEntries being one), false otherwise.
function TypeStore:isOptionalSingleInstanceMapping(mapping)
  return mapping.objectType.minEntries == 0 and mapping.objectType.maxEntries == 1
end

--- Checks if the given mapping contains the given parameter.
-- @param #table mapping The mapping we need to check
-- @param #string parameter The parameter we wish to validate
-- @return #boolean True if the given mapping contains the given parameter,
--                  false otherwise.
function TypeStore:mappingContainsParameter(mapping, parameter)
  return mapping.objectType.parameters[parameter]~=nil
end

--- Checks if the given mapping is a top-level mapping or not.
-- @param #table mapping The mapping we need to check
-- @return #boolean True if the type path of the mapping contains only an
--                  ending dot, false otherwise.
local function isTopLevel(mapping)
  return mapping.dotlevel == 1
end

--- Get the parent mapping of the given mapping, if any.
-- @param #table mapping The mapping for which we need to find the parent.
-- @return #table The mapping of the parent if it exists.
-- @return #nil If no parent can be found.
function TypeStore:parent(mapping)
    local path = mapping.objectType.name
    if self:isMultiInstanceMapping(mapping) then
      -- Strip the placeholder from the path.
      path = stripEnd(path)
    end
    -- Strip the lowest level from the path.
    path = stripEnd(path)
    if #path == 0 then
      --invalid path
      return nil
    end
    return self:get_mapping_exact(path)
end

--- Get the ancestor list of the given mapping
-- @param #table mapping The mapping for which to find the parents list
-- @return #table all ancestors (including the given mapping) keyed on dotlevel
function TypeStore:ancestors(mapping)
  local parents = {}
  while mapping do
    parents[mapping.dotlevel] = mapping
    mapping = self:parent(mapping)
  end
  return parents
end

--- Function to collect all mappings that correspond to the given type path.
-- @param #table self The typestore table.
-- @param #string typepath The type path for which we want all the mappings.
-- @return #table A table containing all the mappings that correspond to the given type
--                path, in path order (The first mapping will be the root mapping).
local function collectMappings(self, typepath)
  -- build the maplist.
  local maplist = {}
  local mapping = self:get_mapping_incomplete(typepath)
  while mapping do
    maplist[mapping.dotlevel] = mapping
    mapping = self:parent(mapping)
  end
  -- Now you have an ordered lists of mappings. The first mapping should be a top level mapping.
  -- If it's not, throw an error.
  if not maplist[1] or not isTopLevel(maplist[1]) then
    fault.InvalidName("invalid path %s", typepath)
  end
  if maplist[#maplist].objectType.name ~= typepath then
    maplist[#maplist] = nil
  end
  return maplist
end

--- Wrapper around the mapping.entries call.
-- @param #table mapping The mapping on which to call entries.
-- @param #table parent_keys The parent keys to use.
-- @return #table The result of the mapping.entries() call if it
--                succeeded. If the entries function returns nil or raises an
--                error, an error is thrown.
-- NOTE: By using get_entries the error handling will be uniform and the code
--       will be easier to read.
local function get_entries(mapping, parent_keys)
  local rc, entries, errmsg = xpcall(mapping.entries, traceback, mapping, unpack(parent_keys))
  if not rc then  -- entries() threw an error; which is returned in 'entries'
    logger:error("entries() threw an error : %s", entries)
    fault.InternalError(entries)
  elseif not entries then  -- entries() returned nil + an error
    fault.InternalError("entries() failed: %s", errmsg or "<no error msg>")
  end
  return entries
end

-- call persistency.sync but improve the error msg by prepending the mapping path
local function db_sync(self, mapping, entries, parent_ireferences)
  local persistency = self.persistency
  local ok, keymap = pcall(persistency.sync, persistency, mapping.tp_id, entries, parent_ireferences)
  if not ok then
    -- include path in error msg
    if type(keymap)=='table' then
      keymap.errmsg = mapping.objectType.name..': '..keymap.errmsg
    end
    -- reraise
    error(keymap)
  end
  return keymap
end

--- Synchronize the given mapping with our database.
-- @param #table The mapping we need to synchronize.
-- @param #table parent_keys The keys of the parent for which we wish to synchronize.
-- @param #table parent_ireferences The instance references of the parent for which
--                                  we wish to synchronize.
-- @return #table The mapping between the keys and instance references known for the
--                given mapping under the given parent.
function TypeStore:synchronize(mapping, parent_keys, parent_ireferences)
  local keymap
  local parent_irefs_string = concat(parent_ireferences, ".")
  if not mapping._entries or not mapping._entries[parent_irefs_string] then
    local entries = get_entries(mapping, parent_keys)
    keymap = db_sync(self, mapping, entries, parent_ireferences)
    if not mapping._entries then
      mapping._entries = {}
    end
    -- Cache the keymap
    mapping._entries[parent_irefs_string] = keymap
    self.entries_cache[mapping] = true
  else
    -- Retrieve cached keymap
    keymap = mapping._entries[parent_irefs_string]
  end
  return keymap
end

--- Check if the given mapping exists for the given parent keys.
-- @param #table The optional single instance mapping we need to check.
-- @param #table parent_keys The keys of the parent for which we wish to check.
-- @return #boolean True if the optional single instance mapping exists for the given
--                  parent keys, false otherwise.
function TypeStore:exists(mapping, parent_keys)
  local parents_key_string = concat(parent_keys, ".")
  if not mapping._entries or not mapping._entries[parents_key_string] then
    local exists = get_entries(mapping, parent_keys)
    if not mapping._entries then
      mapping._entries = {}
    end
    -- Cache the exists result
    if exists and #exists > 0 then
      mapping._entries[parents_key_string] = true
    else
      mapping._entries[parents_key_string] = false
    end
    self.entries_cache[mapping] = true
  end
  return mapping._entries[parents_key_string]
end

--- Find the keys that correspond to the given instance references.
-- This function receives a type path and an array of instance references.
-- for each level in the type path, it will try to retrieve the key for
-- the corresponding instance number.
-- @param typepath The type path for which we need to find all the keys.
-- @param irefs The array of all the instance references in reverse order.
-- @return The array with all the keys in the same order as the instance
--         references array.
function TypeStore:getkeys(typepath, irefs)
  -- For each multi instance type in 'typepath'
  -- we must first sync with the mappers and validate against the
  -- persistency store.
  local count = #irefs + 1 -- The irefs are reversed, so start counting backwards.
  local keys = {}

  for _,mapping in ipairs(collectMappings(self,typepath)) do
    if self:isMultiInstanceMapping(mapping) then
      -- The mapping is multi instance, synchronize before looking for the key.
      -- synchronize will either succeed or throw an error.
      local iks = self:synchronize(mapping, keys, { unpack(irefs, count)})
      count = count - 1
      local key = iks[irefs[count]]
      if not key then
        -- object instance not found so throw an error
        fault.InvalidName("invalid instance")
      end
      insert(keys, 1, key)
    elseif self:isOptionalSingleInstanceMapping(mapping) then
      -- The mapping is optional single instance, check if the instance exists.
      if not self:exists(mapping, keys) then
        -- object instance not found so throw an error
        fault.InvalidName("invalid optional instance")
      end
    end
    -- Mandatory single instances always exist and have no key.
  end
  return keys
end

--- Close down a store.
-- It can not be used anymore after this method has been called.
function TypeStore:close()
  self.persistency:close()
  self.persistency = nil
  self.mappings = nil
end

--- Start or continue a transaction on the persistency layer.
-- @param self The type store on which to start a transaction.
local function startOrContinueTransaction(self, uuid)
  if not self.inTransaction then
    self._client_uuid = uuid
    self.persistency:startTransaction()
    self.inTransaction = true;
  end
end

-- common actions at the end of the transaction
local function endTransaction(self)
  self._client_uuid = nil
  self.inTransaction = false
  for mapping in pairs(self.entries_cache) do
    mapping._entries = nil
  end
  self.entries_cache = {}
end

--- Commit a transaction on the persistency layer.
-- @param self The type store on which to commit the transaction.
local function commitTransaction(self, uuid)
  if self.inTransaction then
    self.persistency:commitTransaction()
    nav.commit(self, uuid)
  end
  endTransaction(self)
end

--- Revert a transaction on the persistency layer.
-- @param self The type store on which to revert the transaction.
local function revertTransaction(self)
  if self.inTransaction then
    self.persistency:revertTransaction()
    nav.revert(self)
  end
  endTransaction(self)
end

--- Wrap the navigate function so a transaction is started if needed.
-- @param #table store The type store on which to navigate.
-- @param #string uuid the client UUID for the transaction
-- @param #string path The path we wish to traverse.
-- @param #string action The action to perform while navigating the tree.
-- @param #number level 0, 1 or 2 are allowed.
-- NOTE: Keep this API in line with the navigate function of the navigator.
--       For a more in depth explanation of the parameters, consult the
--       documentation of the navigator.
--       The client_uuid is not part of the navigator interface but added
--       specifically for the typestore.
local function navigateWrapper(store, client_uuid, path, action, level)
  startOrContinueTransaction(store, client_uuid)
  return nav.navigate(store, path, action, level)
end

--- Get the client UUID for the current transaction
function TypeStore:clientUUID()
  return self._client_uuid
end

function TypeStore:setClientUUID(uuid)
  self._client_uuid = uuid
end


function TypeStore:registerEventhor(eventhor)
  self.eventhor = eventhor
end

local M = {
  new = function(persistency_location, persistency_name)
    local self = {
      persistency = require("transformer.persistency").new(persistency_location,
                                                           persistency_name),
      -- Contains the list of all registered mappings, sorted alphabetically.
      -- In other words, the typetree is flattened depth-first.
      mappings = {},
      --- Return an iterator that will walk over the tree identified
      -- by the given path.
      -- This path can be a partial or exact path.
      -- @param path The path to start navigating from.
      -- @param action Which action to perform during navigation.
      -- @return An iterator that will return the next object each
      --         time it is called. Throws an error if there's something
      --         wrong (path invalid, iteration finds something wrong, ...)
      navigate = navigateWrapper,
      commit = commitTransaction,
      revert = revertTransaction,
      -- Indicates if we are in a transaction or not.
      inTransaction = false,
      entries_cache = {}, -- Cache for the entries function in 1 transaction
    }
    self.alias = alias.new(self)
    return setmetatable(self, TypeStore)
  end
}

return M
