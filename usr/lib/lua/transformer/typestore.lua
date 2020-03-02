--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local format,        gmatch,        find,        sub =
      string.format, string.gmatch, string.find, string.sub
local insert, concat = table.insert, table.concat
local floor = math.floor
local error, unpack, require, setmetatable, assert, ipairs, pairs, next, type =
      error, unpack, require, setmetatable, assert, ipairs, pairs, next, type
local pcall = pcall
local fault = require("transformer.fault")
local nav = require("transformer.navigation")
local alias_module = require("transformer.alias")
local pathFinder = require("transformer.pathfinder")
local logger = require("tch.logger")
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
  return mapping and (mapping.dotlevel == 1)
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

--- Function to collect all mappings in the given typepath.
-- The typepath may be incomplete (i.e. missing the {i} specifier) but in
-- that case the result will not include that mapping.
-- @tstring typepath The typepath for which we want all the mappings.
-- @return #table A table containing all the mappings in the given typepath
--                in path order (the first mapping will be the root mapping).
-- @return #table The deepest multi instance mapping.
function TypeStore:collectMappings(typepath)
  -- build the maplist.
  local maplist = {}
  local mapping = self:get_mapping_incomplete(typepath)
  local last_multi
  while mapping do
    if not last_multi and self:isMultiInstanceMapping(mapping) then
      -- Keep track of the lowest multi instance
      last_multi = mapping
    end
    maplist[mapping.dotlevel] = mapping
    mapping = self:parent(mapping)
  end
  -- Now you have an ordered lists of mappings. The first mapping should be a top level mapping.
  -- If it's not, throw an error.
  if not isTopLevel(maplist[1]) then
    fault.InvalidName("invalid path %s", typepath)
  end
  -- If `typepath` wasn't complete (e.g. "Device.Users.User." is specified instead of
  -- "Device.Users.User.{i}.") then we don't include the User.{i}. mapping in the result.
  if maplist[#maplist].objectType.name ~= typepath then
    maplist[#maplist] = nil
  end
  return maplist, last_multi
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
  local ok, keymap, new_keys = pcall(persistency.sync, persistency, mapping.tp_id, entries, parent_ireferences)
  if not ok then
    -- include path in error msg
    if type(keymap)=='table' then
      keymap.errmsg = mapping.objectType.name..': '..keymap.errmsg
    end
    -- reraise
    error(keymap)
  end
  return keymap, new_keys
end

--- Helper function to ensure we generate a unique alias.
-- @param #string alias The new alias we wish to use.
-- @param #table known_aliases A table of known aliases, with the aliases as keys.
-- @return #string The passed in alias if it was available, a modified version of the alias otherwise.
local function make_alias_unique(alias, known_aliases)
  if #alias > 54 then
    -- We only use the first 54 characters here to avoid breaking the 64 character limit of an alias.
    -- This leaves 10 characters to ensure uniqueness.
    alias = sub(alias, 1, 54)
  end
  known_aliases = known_aliases or {}
  if known_aliases[alias] then
    -- alias was not unique, start appending numbers
    local guess
    local n=0
    repeat
      n = n+1
      guess = alias..n
    until not known_aliases[guess]
    alias = guess
  end
  return alias
end

--- Function to generate a new alias for the given mapping and key.
-- @param #table mapping The mapping we need to generate an alias for.
-- @param #table known_aliases A table of known aliases.
-- @param #string iref The instance reference to be used by the object with the given key.
-- @param #string key The key of the object for which to generate an alias.
-- @param #string parentkey The optional parentkey/grandparentkey/... of the object.
-- @return #string A new alias for the given mapping and key.
function TypeStore:generateAlias(mapping, known_aliases, iref, key, ...)
  -- First we generate a base for the alias
  local base
  if mapping.aliasDefault then
    base = nav.get_parameter_value(mapping, mapping.aliasDefault, key, ...)
  else
    local name = mapping.objectType.name:gsub("%.{i}%.$", "."):match("([^%.]+)%.$") or ""
    local index = iref or ""
    base = name.."-"..index
  end
  -- Then we ensure it's unique by checking it against the known aliases.
  local alias = make_alias_unique("cpe-"..base, known_aliases)
  -- Finally we persist it.
  self.persistency._db:setAliasForKey(mapping.tp_id, key, alias)
  return alias
end

--- Synchronize the given mapping with our database.
-- @param #table mapping The mapping we need to synchronize.
-- @param #table parent_keys The keys of the parent for which we wish to synchronize.
-- @param #table parent_ireferences The instance references of the parent for which
--                                  we wish to synchronize.
-- @return #table, #table The mapping between the instance references and keys known for the
--                        given mapping under the given parent is the first return value.
--                        Additionally the array part of the table contains the irefs in a
--                        somewhat-natural order. Note that this hybrid nature of the table
--                        implies you can't just use pairs() to iterate it; you should use ipairs().
--                        The second return value is a mapping between the new aliases and the
--                        instance references for the given mapping under the given parent.
function TypeStore:synchronize(mapping, parent_keys, parent_ireferences)
  local keymap, new_keys, new_aliases
  new_aliases = {}
  local parent_irefs_string = concat(parent_ireferences, ".")
  if not mapping._entries or not mapping._entries[parent_irefs_string] then
    local entries = get_entries(mapping, parent_keys)
    keymap, new_keys = db_sync(self, mapping, entries, parent_ireferences)
    if mapping.objectType.aliasParameter and new_keys and next(new_keys) then
      -- First retrieve the parent DB object, so we can check the generated aliases for uniqueness.
      local known_aliases = self.persistency:getKnownAliases(mapping.tp_id, parent_ireferences)
      for iref, key in pairs(new_keys) do
        local alias = self:generateAlias(mapping, known_aliases, iref, key, unpack(parent_keys))
        known_aliases[alias] = true
        new_aliases[alias] = iref
      end
    end
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
  return keymap, new_aliases
end

--- Check if the given mapping exists for the given parent keys.
-- @param #table mapping The optional single instance mapping we need to check.
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
-- This function receives a list of mappings and an array of instance references.
-- For each mapping in the list, it will try to retrieve the key for
-- the corresponding instance number. If the list of mappings contain optional
-- single instance types it will check if the instance exists for the given
-- ancestors.
-- @param #table mappings An array of mappings for which we need to find all the keys.
-- @param #table irefs The array of all the instance references in reverse order.
-- @param #table aliases The array of all aliases in reverse order.
-- @param no_sync Boolean indicating the implementation shouldn't sync
--                multi-instance mappings.
-- @return #table, #table The array with all the keys in the same order as the instance
--                        references array is the first return value. The second return
--                        value is the instance references array with all aliases replaced
--                        by the actual instance references.
function TypeStore:getkeys(mappings, irefs, aliases, no_sync)
  -- For each multi instance type in 'mappings'
  -- we must first sync with the mappers and validate against the
  -- persistency store.
  local count = #irefs + 1 -- The irefs are reversed, so start counting backwards.
  local keys = {}

  for _, mapping in ipairs(mappings) do
    if self:isMultiInstanceMapping(mapping) then
      local key
      if no_sync then
        -- No sync means no aliases
        count = count - 1
        local current_irefs = { unpack(irefs, count) }
        key = self.persistency:getKey(mapping.tp_id, current_irefs)
      else
        -- The mapping is multi instance, synchronize before looking for the key.
        -- synchronize will either succeed or throw an error.
        local parent_irefs = { unpack(irefs, count) }
        count = count - 1
        local iks, new_aliases = self:synchronize(mapping, keys, parent_irefs)
        if aliases and aliases[count] == irefs[count] then
          if not new_aliases[aliases[count]] then
            -- We have an alias we can't translate to an instance number.
            fault.InvalidName("invalid instance")
          end
          irefs[count] = new_aliases[aliases[count]]
        end
        key = iks[irefs[count]]
      end
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
  return keys, irefs
end

--- Convert a list of aliases to their corresponding instance references.
-- @param #table mappings An array of mappings for which we need to translate find all the aliases.
-- @param #table aliases An array of the aliases we need to translate.
-- @param #table irefs An array of instance references we already know. This array contains aliases in the spots
--                     we need to convert.
-- @return #table The given array of instance references, completed as much as possible by replacing all aliases with
--                the corresponding instance references. There is however no guarantee that all aliases will be replaced,
--                as a synchronization might be required.
-- @note The length of the given aliases array needs to be the same as the length of the given instance references array.
function TypeStore:convertAliasesToIrefs(mappings, aliases, irefs)
  local count = #irefs + 1 -- The irefs are reversed, so start counting backwards.
  for _, mapping in ipairs(mappings) do
    if self:isMultiInstanceMapping(mapping) then
      count = count - 1
      if aliases[count] == irefs[count] then
        -- We received an alias on this level, retrieve the associated iref.
        local iref = self.persistency:getIreferenceByAlias(mapping.tp_id, aliases[count])
        if iref then
          -- Only replace the alias if we found an alias, don't create a hole.
          irefs[count] = iref
        end
      end
    end
  end
  return irefs
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
    self.alias = alias_module.new(self)
    return setmetatable(self, TypeStore)
  end
}

return M
