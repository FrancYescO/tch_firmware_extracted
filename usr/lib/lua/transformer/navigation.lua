--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

---
-- The idiom to use in Transformer navigation is:
--     for obj in navigate(store, path, action, level) do
--       do something with 'obj', if applicable
--       for param in obj:params() do
--         do something with 'param'
--       end
--     end
-- Depending on the path and the action you provide the iterator
-- will return different things and their methods will behave
-- differently.
-- This behavior is driven by the information stored in the 'it_state',
-- the iteration state. By setting a suitable metatable on that state
-- it behaves like an object, object type or parameter and the
-- methods change their behavior based on the information in 'it_state'.

local gsub, match, find = string.gsub, string.match, string.find
local insert, remove = table.insert, table.remove
local wrap, yield = coroutine.wrap, coroutine.yield
local tonumber, assert, type, unpack, next, pairs, ipairs =
      tonumber, assert, type, unpack, next, pairs, ipairs
local setmetatable = setmetatable

local checkValue = require("transformer.typecheck").checkValue
local fault = require("transformer.fault")

local pathFinder = require("transformer.pathfinder")

local divideInPathParam,            objectPathToTypepath,            typePathToObjPath =
      pathFinder.divideInPathParam, pathFinder.objectPathToTypepath, pathFinder.typePathToObjPath
local endsWithPlaceholder,            endsWithPassThroughPlaceholder =
      pathFinder.endsWithPlaceholder, pathFinder.endsWithPassThroughPlaceholder

local logger = require("tch.logger")

local xpcall = require ("tch.xpcall")
local traceback = debug.traceback

-- This table tracks which paths and mappings have been altered (set, add, delete)
-- and how they were altered.
-- tracker = {
--    mapping1 = {
--      set = {path1, path2, ...},
--      add = {path3, path4, ...},
--      delete = {path5, path6, ...},
--    },
--    mapping2 = {
--      ...
--    },
--    ...
-- }
local tracker = {}

local mt_inner = {}

--- An __index metamethod that creates and adds a new table when an access is made
-- to a previously unknown key.
-- @param #table t The table on which the lookup failed.
-- @param #unknown key The key for which the lookup failed.
-- @return #table A new table is added to the given table at the given key index.
mt_inner.__index = function(t,key)
  local v = {}
  rawset(t,key,v)
  return v
end

local mt_outer = {}
--- An __index metamethod that creates and adds a new table when an access
-- is made to a previously unknown key. This new table has itself
-- a metatable set which acts similarly.
-- @param #table t The table on which the lookup failed.
-- @param #unknown key The key for which the lookup failed.
-- @return #table A new table is added to the given table at the given key index.
--                The metatable of this new table is set to mt_inner.
mt_outer.__index = function(t,key)
  local v = setmetatable({},mt_inner)
  rawset(t,key,v)
  return v
end

setmetatable(tracker, mt_outer)

--- Add a path and action to track.
-- @param #table mapping The mapping on which the operation is performed.
-- @param #string path The path on which the operation is performed. This should not contain any aliases.
-- @param #string operation The operation that is being performed.
local function track(mapping, path, operation)
  logger:debug("tracking %s on %s: %s", path, mapping.objectType.name, operation)
  local operationlist = tracker[mapping][operation]
  operationlist[#operationlist+1] = path
end

--- Call the commit function of all mappings that were being tracked.
local function commit_tracked(store, uuid)
  for mapping,operations in pairs(tracker) do
    if type(mapping.commit) == "function" then
      logger:debug("committing mapping: %s", mapping.objectType.name)
      local rc, committed, errmsg = xpcall(mapping.commit, traceback, mapping)
      if (not rc)  then
        logger:error("commit() on mapping %s threw an error: %s", mapping.objectType.name, committed)
      elseif (not committed and errmsg) then
        logger:error("commit() on mapping %s returned an error: %s ", mapping.objectType.name, errmsg)
      end
    else
      logger:debug("mapping %s does not have a commit function", mapping.objectType.name)
    end
    store.eventhor:queueEvents(uuid, mapping, operations)
  end
  tracker = setmetatable({}, mt_outer)
  store.eventhor:fireEvents()
end

--- Call the revert function of all mappings that were being tracked.
local function revert_tracked(store)
  for mapping,_ in pairs(tracker) do
    if type(mapping.revert) == "function" then
      logger:debug("reverting mapping: %s", mapping.objectType.name)
      local rc, reverted, errmsg = xpcall(mapping.revert, traceback, mapping)
      if (not rc) then
        logger:error("revert() on mapping %s threw an error: %s", mapping.objectType.name, reverted)
      elseif (not reverted and errmsg) then
        logger:error("revert() on mapping %s returned an error: %s", mapping.objectType.name, errmsg)
      end
    else
      logger:debug("mapping %s does not have a revert function", mapping.objectType.name)
    end
  end
  tracker = setmetatable({}, mt_outer)
  store.eventhor:dropEvents()
end

--- Handle changes to the numEntries parameter
local function numEntriesChanged(store, mapping, parent_irefs)
  if mapping.objectType and mapping.objectType.numEntriesParameter then
    local parent = store:parent(mapping)
    if parent then
      local numEntries = typePathToObjPath(parent.objectType.name, parent_irefs)..mapping.objectType.numEntriesParameter
      track(parent, numEntries, "set")
    end
  end
end

local function get_parameter_value(mapping, paramname, key, ...)
  local pvalue
  local getter
  local get = mapping.get
  local type_get = type(get)

  if type_get == "function" then
    getter = get
  elseif type_get == "table" then
    getter = get[paramname]
  end
  type_get = type(getter)
  if type_get == "function" then
    local rc, errmsg
    rc, pvalue, errmsg = xpcall(getter, traceback, mapping, paramname, key, ...)
    if not rc then  -- getter threw an error, which is returned in 'pvalue'
      logger:error("getter(%s, %s) threw an error: %s", mapping.objectType.name, paramname, pvalue)
      fault.InternalError("get(%s, %s) failed: %s", mapping.objectType.name, paramname, pvalue)
    elseif not pvalue then  -- getter returned nil + an error (or returned false)
      fault.InternalError("get(%s, %s) failed: %s", mapping.objectType.name, paramname, (errmsg or "invalid value"))
    end
  elseif type_get == "string" then
    pvalue = getter
  else
    fault.InternalError("unknown %s for param '%s' (%s)", "getter", paramname, type_get)
  end
  return pvalue
end

-- Metatable to let the iteration state behave like a parameter.
local Param = {}
Param.__index = Param

--- Get the value of the parameter
-- @return object path, parameter name, parameter value, parameter type
-- or raises an error
function Param:get()
  local all_values = self.all_values
  local paramname = self.paramname
  local mapping = self.mapping
  local param = mapping.objectType.parameters[paramname]
  local pvalue

  if all_values then
    -- If the parameter value is already retrieved, use it unless the
    -- parameter definition forces us not to or it's a hidden parameter.
    if not param.single and not param.hidden then
      pvalue = all_values[paramname]
    end
  end

  if not pvalue then
    pvalue = get_parameter_value(mapping, paramname, unpack(self.keys))
  end
  return self.objpath, paramname, pvalue, param.type
end

--- Get the parameter name
-- @return object path, parameter name
function Param:getName()
  return self.objpath, self.paramname
end

--- Set the value of the parameter
-- @return true
-- or raises an error
function Param:set(value)
  local paramname = self.paramname
  local mapping = self.mapping

  local paraminfo = mapping.objectType.parameters[paramname]
  local fullPath = mapping.objectType.name..paramname
  if paraminfo.access ~= 'readWrite' then
    fault.InvalidWrite("%s is not writable", paramname)
  end

  value = checkValue(value, paraminfo, fullPath)

  local setter
  local set = mapping.set
  local type_set = type(set)
  if type_set == "function" then
    -- one function for all parameters
    setter = set
  elseif type_set == "table" then
    -- a function per parameter
    setter = set[paramname]
  end

  type_set = type(setter)
  if type_set == "function" then
    local pcr, svalue, errmsg = xpcall(setter, traceback, mapping, paramname, value, unpack(self.keys))
    if not pcr then
      -- setter threw an error
      logger:error("setter threw an error: %s", svalue)
      fault.InternalError("set() failed: %s", svalue)
    elseif not svalue and errmsg then
      -- setter returned nil + error msg
      -- note that we allow that the setter returns nothing at all
      fault.InvalidValue("set() failed: %s", errmsg)
    end
  else
    fault.InternalError("unknown %s for param '%s' (%s)", "setter", paramname, type_set)
  end
  track(mapping, typePathToObjPath(fullPath, self.irefs), "set")
  return true
end

--- Ask whether the parameter is writable.
-- @return True if the parameter can be set using SPV and false otherwise.
function Param:isWritable()
  local paramname = self.paramname
  local paraminfo = self.mapping.objectType.parameters[paramname]
  return self.objpath, paramname, (paraminfo.access == "readWrite")
end

--- Ask whether the parameter is canDeny.
-- @return True if the parameter can deny events and false otherwise.
function Param:isCanDeny()
  local paraminfo = self.mapping.objectType.parameters[self.paramname]
  return (paraminfo~=nil and paraminfo.activeNotify == "canDeny")
end

-- Metatable to let the iteration state behave like an object.
local Object = {}
Object.__index = Object

--- Delete the object.
-- @return true
-- or raises an error.
function Object:delete()
  local mapping = self.mapping
  local objtype = mapping.objectType
  if objtype.access ~= 'readWrite' then
    fault.InvalidName("%s is not writable", objtype.name)
  end

  local delete = mapping.delete
  if type(delete) ~= "function" then
    fault.InternalError("unknown delete function for path: %s", objtype.name)
  end

  --call the delete function
  local pcr, svalue, errmsg = xpcall(delete, traceback, mapping, unpack(self.keys))
  if not pcr then
    -- delete threw an error
    logger:error("delete() threw an error: %s", svalue)
    fault.InternalError("delete() failed: %s", svalue)
  elseif not svalue then
    -- delete returned nil + error msg
    fault.InternalError("delete() failed: %s", errmsg or "-")
  end

  track(mapping, typePathToObjPath(objtype.name, self.irefs), "delete")
  -- delete worked, delete from persistency.
  -- This will only take effect when commit is called.
  self.store.persistency:delKey(mapping.tp_id, self.irefs)
  local key = remove(self.irefs, 1)
  numEntriesChanged(self.store, mapping, self.irefs)
  insert(self.irefs, 1, key)
  return true
end

--- Check if the object is writable, meaning it can be deleted.
-- @return true if the object can be deleted, false if it can't be
--         deleted and nil if it's not applicable.
function Object:isWritable()
  if self.is_exact_path or self.level == 1 then
    return nil
  end
  return self.objpath, (self.mapping.objectType.access == "readWrite")
end

--- Get the object's full datamodel path.
-- @treturn string The full datamodel path of this object.
function Object:getPath()
  return self.objpath
end

local function empty()
end

--- Parameter iterator that returns only one parameter
-- (the one named in it_state.paramname)
local function exact_params_it(it_state)
  if it_state.is_exact_path then
    it_state.is_exact_path = nil
    return it_state
  end
  it_state.paramname = nil
  return nil
end

--- Parameter iterator that returns all parameters.
local function all_params_it(it_state)
  it_state.paramname = next(it_state.mapping.objectType.parameters, it_state.paramname)
  if it_state.paramname then
    return it_state
  end
  it_state.all_values = nil
  return nil
end

--- Return an iterator for all the parameters of the object that are
-- relevant to the request.
function Object:params()
  setmetatable(self, Param)
  if self.is_exact_path then
    return exact_params_it, self
  end
  if self.level == 0 then
    return empty
  end
  if self.action == "get" then
    local mapping = self.mapping
    if mapping.getall  then
      local ok, values = xpcall(mapping.getall, traceback, mapping, unpack(self.keys))
      if ok then
        self.all_values = values
      else
        logger:error("getall() of %s failed: %s", mapping.objectType.name, values)
        self.all_values = nil
      end
    else
      self.all_values = nil
    end
  end
  return all_params_it, self
end

-- Metatable to let the iteration state behave like an object type.
local Objtype = {}
Objtype.__index = Objtype

--- Add another object of the same type.
-- @return instance number of new object, key if path is named multi-instance
-- @param name optional name to be used for new named multi-instance object
-- or raises an error.
function Objtype:add(name)
  local mapping = self.mapping
  local objtype = mapping.objectType
  if objtype.access ~= 'readWrite' then
    fault.InvalidName("%s is not writable", objtype.name)
  end
  local objtype_passThrough_MI = endsWithPassThroughPlaceholder(objtype.name)

  if name then
    if type(name) ~= 'string' or #name == 0 then
      fault.InvalidName("invalid name")
    end
    if not objtype_passThrough_MI then
      fault.InvalidName("%s is not pass-through multi-instance", objtype.name)
    end
  end

  local add = mapping.add
  if type(add) ~= "function" then
    fault.InternalError("unknown add function for path: %s", objtype.name)
  end
  --call the add function
  local pcr, svalue, errmsg
  if objtype_passThrough_MI then
    pcr, svalue, errmsg = xpcall(add, traceback, mapping, name, unpack(self.keys))
  else
    pcr, svalue, errmsg = xpcall(add, traceback, mapping, unpack(self.keys))
  end
  if not pcr then
    -- add threw an error
    logger:error("add() threw an error: %s", svalue)
    fault.InternalError("add() failed: %s", svalue)
  elseif not svalue then
    -- add returned nil + error msg
    fault.InternalError("add() failed: %s", errmsg or "<no error msg>")
  end
  -- success
  -- addKey will either succeed or throw an error
  local instance = self.store.persistency:addKey(mapping.tp_id, self.irefs, svalue)
  if mapping.objectType.aliasParameter then
    -- Add an alias for the new instance (if needed)
    local known_aliases = self.store.persistency:getKnownAliases(mapping.tp_id, self.irefs)
    self.store:generateAlias(mapping, known_aliases, instance, svalue, unpack(self.keys))
  end
  insert(self.irefs, 1, instance)
  local objPath = typePathToObjPath(objtype.name, self.irefs)
  remove(self.irefs, 1)
  track(mapping, objPath, "add")
  numEntriesChanged(self.store, mapping, self.irefs)
  return instance
end

--- Delete all instances of this object type.
function Objtype:delete()
  local mapping = self.mapping
  local objtype = mapping.objectType
  if objtype.access ~= 'readWrite' then
    fault.InvalidName("%s is not writable", objtype.name)
  end

  local deleteall = mapping.deleteall
  if deleteall then
    if type(deleteall) ~= "function" then
      fault.InternalError("unknown deleteall function for path: %s", objtype.name)
    end

    --call the deleteall function
    local pcr, svalue, errmsg = xpcall(deleteall, traceback, mapping, unpack(self.keys))
    if not pcr then
      -- delete threw an error
      logger:error("deleteall() threw an error: %s", svalue)
      fault.InternalError("deleteall() failed: %s", svalue)
    elseif not svalue then
      -- delete returned nil + error msg
      fault.InternalError("deleteall() failed: %s", errmsg or "-")
    end

    -- delete worked
    insert(self.irefs, 1, "dummy_iref") -- Add a dummy to make typePathToObjPath work
    local objpath = typePathToObjPath(objtype.name, self.irefs)
    remove(self.irefs, 1)
    objpath = objpath:match("^(.*)%..dummy_iref$")
    track(mapping, objpath, "deleteall")

    local persistency = self.store.persistency
    -- TODO delete from persistency, implement recursive delete
    logger:critical("deleteall on %s: recursive delete not implemented", objtype.name)
    return true
  end
  -- When the mapping doesn't have a deleteall function we
  -- have to fall back to each instance's delete function.
  -- To accomplish this we have to set 'level' to 1 so when we
  -- return into the iterator it doesn't stop but continues
  -- with the children
  self.level = 1
end

--- Check if the object type is writable, meaning new instances
-- can be added.
-- @return true if new instances can be added, false otherwise
function Objtype:isWritable()  -- only called when objtype is MI
  local objtype = self.mapping.objectType
  return self.objpath, (objtype.access == "readWrite")
end

--- Return an iterator for all the parameters of the object type
-- that are relevant to the request. At this moment there are none
-- so this always returns an empty iterator.
function Objtype:params()
  return empty
end

-- forward declaration
local output_instance

--- Iterator for (optionally) object type and object instances, starting from
-- a path ending in a MI object type.
-- Depending on the value of the it_state.level field it continues
-- recursively with child object types and objects.
local function output_all(it_state)
  -- the object type should only be yielded in the relevant GPN
  -- requests, on an ADD or on a DELETE of all instances (in which
  -- case 'level' is set to 0 so we stop the iteration after having
  -- yielded the object type)
  if it_state.level == 2 or it_state.level == 0 then
    setmetatable(it_state, Objtype)
    yield(it_state)
    if it_state.level == 0 then
      return
    end
  end
  if it_state.level == 1 then
    -- only the immediate children should be yielded
    -- and then the iteration should stop
    it_state.level = 0
  end
  local mapping = it_state.mapping
  local typepath = mapping.objectType.name
  local keys = it_state.keys
  local irefs = it_state.irefs
  local aliases = it_state.aliases
  -- synchronize will either succeed or throw an error.
  local iks = it_state.store:synchronize(mapping, keys, irefs)
  for _, iref in ipairs(iks) do
    local key = iks[iref]
    insert(irefs, 1, iref)
    insert(keys, 1, key)
    insert(aliases, 1, "")
    it_state.objpath = typePathToObjPath(typepath, irefs, aliases)
    output_instance(it_state)
    remove(irefs, 1)
    remove(keys, 1)
    remove(aliases, 1)
    it_state.mapping = mapping
  end
end

--- Iterator for (optionally) object type and object instances, starting from
-- a path ending in an object instance.
-- Depending on the value of the it_state.level field it continues
-- recursively with child object types and objects or only yields
-- the instance and nothing more.
output_instance = function(it_state)
  if it_state.store:isOptionalSingleInstanceMapping(it_state.mapping) and
     not it_state.store:exists(it_state.mapping, it_state.keys) then
    return
  end
  setmetatable(it_state, Object)
  yield(it_state)
  if it_state.level == 0 then
    -- return after yielding the instance itself
    return
  end
  if it_state.level == 1 then
    -- only the immediate children should be yielded
    -- and then the iteration should stop
    it_state.level = 0
  end
  local objpath = it_state.objpath
  for childmapping in it_state.store:children(it_state.mapping) do
    local objtype = childmapping.objectType
    it_state.mapping = childmapping
    -- (optional) single instance objtype?
    if objtype.maxEntries == 1 then
      it_state.objpath = typePathToObjPath(objtype.name, it_state.irefs, it_state.aliases)
      output_instance(it_state)
    else
      local lastname = match(objtype.name, "%.([^%.]+%.)[^%.]+%.$")
      it_state.objpath = objpath .. lastname
      output_all(it_state)
    end
  end
end

-- This is the list of actions and their supported methods.
-- Each action is a table and each supported method is a function within that
-- table.
-- The function take a single parameter, the it_state, and returns an iterator.
-- Methods that are not supported for a specific action will not have a
-- function in the table.
--
-- The methods are:
--   exact_path : executed for exact paths
--   instance : executed for paths designating a specific instance (single or
--              multi instance)
--   subtree : executed for paths that specify the root of multi instance
--             subtree (so without an instance number)
local actions = {
  get = {
    exact_path = function(it_state)
      it_state.level = 0
      return wrap(output_instance), it_state
    end,
    instance = function(it_state)
      return wrap(output_instance), it_state
    end,
    subtree = function(it_state)
      return wrap(output_all), it_state
    end
  },

  getpn = {
    exact_path = function(it_state)
      -- GPN on exact path is only allowed when level == 2
      if it_state.level ~= 2 then
        fault.InvalidArguments("GPN on exact path and level~=2")
      end
      -- we only need to output the parameter itself so
      -- set the level to 0
      it_state.level = 0
      return wrap(output_instance), it_state
    end,
    instance = function(it_state)
      -- GPN on instance path is only allowed when level == 0 or 1 or 2
      local level = it_state.level
      if level ~= 0 and level ~= 1 and level ~= 2 then
        fault.InvalidArguments("GPN on instance and level~={0,1,2}")
      end
      return wrap(output_instance), it_state
    end,
    subtree = function(it_state)
      -- GPN on subtree is only allowed when level == 1 or 2
      local level = it_state.level
      if level ~= 1 and level ~= 2 then
        fault.InvalidArguments("GPN on subtree and level~={1,2}")
      end
      return wrap(output_all), it_state
    end
  },

  set = {
    exact_path = function(it_state)
      it_state.level = 0
      return wrap(output_instance), it_state
    end
  },

  add = {
    subtree = function(it_state)
      it_state.level = 0
      return wrap(output_all), it_state
    end
  },

  del = {
    instance = function(it_state)
      it_state.level = 0
      return wrap(output_instance), it_state
    end,
    subtree = function(it_state)
      it_state.level = 0
      return wrap(output_all), it_state
    end
  }
}
-- actions for getParameterList are the same as for get.
-- But we must use a different actionName as otherwise getall may be called
-- when we do not need the parameter values
actions.getlist = actions.get


--- execute the given method for the given action
-- @param actionName the action (get, set, add, del, ...)
-- @param methodName the method (exact_path, instance, subtree)
-- @param it_state the iteration state
-- @param path the original full path
local function do_action(actionName, methodName, it_state, path)
  local action = actions[actionName]
  if action then
    local method = action[methodName];
    if method then
      return method(it_state)
    end
  end
  fault.InvalidName("%s not supported on %s", methodName, path)
end


--- Navigate the given type store over the given path.
-- This method will create an iterator for the mappings that match the
-- given path. This iterator will return objects that represent instances
-- and which contain a params() function. This params() function will in turn
-- iterate over the parameters of an instance.
-- @param store The type store over which we need to navigate.
-- @param path The path we wish to traverse.
--         There are two types of paths:
--         1) Exact paths: fully qualified path to a specific parameter of a
--              specific instance
--         2) Partial paths: path that identifies the starting node from which
--              you want the subtree.
--              There are three types of partial paths:
--                2.1) ...SI.    -> all parameters of this instance
--                2.2) ...MI.i.  -> all parameters of this instance
--                2.3) ...MI.    -> all parameters of all instances
-- @param action The action to perform while navigating the tree.
-- @param level Number (0, 1 or 2 are allowed) indicating whether to restrict
--              the results to only that level in the datamodel hierarchy.
--              For more information on the meaning of this parameter see
--              ./doc/getparameternames.md
local function navigate(store, path, action, level)
  -- split path in object and (optionally) param part
  local objpath, paramname = divideInPathParam(path)
  if not objpath then
    -- failed to parse path so throw error
    fault.InvalidName("invalid path %s", path)
  end

  -- the path is exact if a parameter name was supplied.
  local is_exact_path = (0 ~= #paramname)

  -- Parse out the instance numbers, aliases and names from the path.
  -- They are stored in reverse order.
  local typepath, irefs, aliases = objectPathToTypepath(objpath)
  -- irefs at this point contains aliases as well. These need to be converted to
  -- proper instance references.
  local mappings = store:collectMappings(typepath)
  irefs = store:convertAliasesToIrefs(mappings, aliases, irefs)

  -- Now resolve the instance numbers to keys.
  local keys, irefs = store:getkeys(mappings, irefs, aliases)
  assert(#irefs == #keys)

  -- This is guaranteed to succeed after getkeys.
  local mapping = store:get_mapping_incomplete(typepath)
  -- Create iterator state.
  local it_state = {
    action = action,
    store = store,
    mapping = mapping,
    paramname = paramname,
    irefs = irefs,
    aliases = aliases,
    keys = keys,
    objpath = objpath,
    level = level,
    is_exact_path = is_exact_path,
    all_values = nil  -- filled in later in Object:params() when action == "get"
                      -- and the mapping provides a getall() callback
  }

  -- is it an exact path?
  if is_exact_path then
    -- check that the parameter exists
    if mapping.objectType.name ~= typepath or not mapping.objectType.parameters[paramname] then
      fault.InvalidName("invalid exact path %s", path)
    end
    return do_action(action, "exact_path", it_state, path)
  end

  -- it's not an exact path but a partial path
  it_state.paramname = nil
  it_state.mapping = mapping
  if not store:isMultiInstanceMapping(mapping) or endsWithPlaceholder(typepath) then
    -- partial path of type 2.1 or 2.2
    return do_action(action, "instance", it_state, path)
  end
  -- partial path of type 2.3
  return do_action(action, "subtree", it_state, path)
end

local M = {
  navigate = navigate,
  commit = commit_tracked,
  revert = revert_tracked,

  get_parameter_value = get_parameter_value,
}

return M
