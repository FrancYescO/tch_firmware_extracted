--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local find, format, byte, match = string.find, string.format, string.byte, string.match
local require, type, error, loadfile, setfenv, getfenv, setmetatable, pcall =
      require, type, error, loadfile, setfenv, getfenv, setmetatable, pcall
local pairs, ipairs, tostring, rawset, next =
      pairs, ipairs, tostring, rawset, next
local lfs = require("lfs")
local logger = require("transformer.logger")
local maphelper = require 'transformer.maphelper'
local xref = require 'transformer.xref'
local xpcall = require ("tch.xpcall")
local traceback = debug.traceback

local default_hidden_values = {
  base64 = "",
  hexBinary = "",
  string = "",
  unsignedInt = "0",
  unsignedLong = "0",
  int = "-1",
  long = "-1",
  boolean = "false",
  dateTime = "0001-01-01T00:00:00Z",
  password = ""
}

local function should_be_unhidden(path, unhide_patterns)
  if unhide_patterns then
    for _, unhide in ipairs(unhide_patterns) do
      if match(path, unhide) then
        return true
      end
    end
  end
  return false
end

local function hidden_mapping(mapping, unhide_patterns)
  local objtype = mapping.objectType
  local result
  for pname, ptype in pairs(objtype.parameters) do
    if ptype.hidden then
      if should_be_unhidden(objtype.name..pname, unhide_patterns) then
        ptype.hidden = nil
      else
        if not result then
          result = {}
        end
        local returned_value = ptype.default
        if not returned_value then
          returned_value = default_hidden_values[ptype.type] or ""
        end
        result[pname] = returned_value
      end
    end
  end
  if result and next(result) then
    maphelper.wrap_get(mapping)
    for pname, pvalue in pairs(result) do
      mapping.get[pname] = pvalue
    end
  end
end

--- make sure alias parameter is not present in getall
local function alias_getall(mapping, ...)
  local rv = mapping._real_getall(mapping, ...)
  rv[mapping.objectType.aliasParameter] = nil
  return rv
end

local function alias_mapping(store, mapping)
  local get, set = store.alias.accessors(mapping)
  if get then
    local aliasParam = mapping.objectType.aliasParameter
    maphelper.wrap_get(mapping)
    maphelper.wrap_set(mapping)
    mapping.get[aliasParam] = get
    mapping.set[aliasParam] = set
    if mapping.getall then
      mapping._real_getall = mapping.getall
      mapping.getall = alias_getall
    end
  end
end

local function is_ignored(path, ignore_patterns, vendor_patterns)
  if ignore_patterns then
    for _, ignore in ipairs(ignore_patterns) do
      if match(path, ignore) then
        return true
      end
    end
  end
  -- Vendor whitelist patterns only apply to Vendor-Specific Parameters which are not
  -- provided by Technicolor itself (000E50 is our OUI).
  if match(path, "%.X_") and not match(path, "%.X_000E50_") then
    if not vendor_patterns then
      return true
    end
    for _, vendor in ipairs(vendor_patterns) do
      if match(path, vendor) then
        return false
      end
    end
    return true
  end
  return false
end

-- check a whole bunch of properties of a mapping and throw an
-- error if we find something wrong with it.
--@return True if the mapping validated, nil + reason otherwise.
--TODO: Refactor so no errors are thrown during registration.
local function validate_mapping(mapping, ignore_patterns, vendor_patterns)
  local objtype = mapping.objectType
  if type(objtype) ~= "table" then
    error("no objectType defined", 3)
  end
  local name = objtype.name
  if type(name) ~= "string" then
    error("objectType.name not a string", 3)
  end
  -- checking if objtype name ends in a dot
  -- note: we're assuming ASCII (46 is decimal value of the dot in ASCII)
  if byte(objtype.name, #objtype.name) ~= 46 then
    error(format("'%s' doesn't end with a dot", name), 3)
  end
  -- Generate a warning if the objtype is a vendor extension and there's no description.
  -- note: 'name' will match if .X_ appears anywhere in the full name of the objtype
  -- i.e. also when this mapping registers an objtype that itself doesn't have the X_
  -- in its name but one of its ancestors has.
  if match(name, "%.X_") and not (objtype.description) then
      logger:warning("'%s': no description", name)
  end
  -- We remove 'objtype.description' in memory because it's not needed at runtime.
  objtype.description = nil
  -- If we ignore the object type, we throw an error to invalidate the mapping.
  if is_ignored(name, ignore_patterns, vendor_patterns) then
    return nil, format("'%s' is actively ignored", name)
  end
  -- If the numEntriesParameter is present, object must be multi instance.
  if objtype.numEntriesParameter and not (objtype.maxEntries > 1) then
    error(format("'%s': %s only valid for multi instance", name, "numEntriesParameter"), 3)
  end
  -- If the numEntriesParameter is a vendor extension, we possibly need to ignore it.
  if objtype.numEntriesParameter and is_ignored("."..objtype.numEntriesParameter, ignore_patterns, vendor_patterns) then
    objtype.numEntriesParameter = nil
  end
  if type(objtype.parameters) ~= "table" then
    error(format("'%s': no 'parameters' table", name), 3)
  end
  if type(objtype.maxEntries) ~= "number" then
    error(format("'%s': '%s' not a %s", name, "maxEntries", "number"), 3)
  end
  if type(objtype.minEntries) ~= "number" then
    error(format("'%s': '%s' not a %s", name, "minEntries", "number"), 3)
  end
  -- possible values for minEntries and maxEntries:
  --  min = 0, max = 1 --> optional SI
  --  min = 0 or min = 1, max > 0 --> MI
  --  min = 1, max = 1 --> SI
  --  all the rest is not valid/supported
  if objtype.minEntries == 0 then
    -- optional SI or MI
    if objtype.maxEntries < 0 then
      error(format("'%s': %s must be > 0", name, "maxEntries"), 3)
    end
    -- Optional SI and MI objtypes must have an 'entries' function.
    if type(mapping.entries) ~= "function" then
      error(format("'%s': %s > 1 but no 'entries' function defined", name, "maxEntries"), 3)
    end
    -- MI objtypes must end in ".{i}." or ".{@}."
    if objtype.maxEntries > 1 and (not find(name, "%.{i}%.$") and not find(name, "%.@%.$")) then
      error(format("'%s' is multi instance but doesn't end with '.{i}.' or '.@.'", name), 3)
    end
  elseif objtype.minEntries == 1 then
    if objtype.maxEntries < 1 then
      error(format("'%s': if %s == 1 then %s must be >= 1", name, "minEntries", "maxEntries"), 3)
    end
    -- MI objtypes must have an 'entries' function.
    if objtype.maxEntries > 1 and type(mapping.entries) ~= "function" then
      error(format("'%s': %s > 1 but no 'entries' function defined", name, "maxEntries"), 3)
    end
    -- MI objtypes must end in ".{i}." or ".{@}."
    if objtype.maxEntries > 1 and (not find(name, "%.{i}%.$") and not find(name, "%.@%.$")) then
      error(format("'%s' is multi instance but doesn't end with '.{i}.' or '.@.'", name), 3)
    end
  else
    error(format("'%s': invalid combination of %s en %s", name, "minEntries", "maxEntries"), 3)
  end
  if objtype.access == "readWrite" then
    if objtype.maxEntries == 1 then
      error(format("'%s': readWrite objects should have %s > 1", name, "maxEntries"), 3)
    end
    if type(mapping.add) ~= "function" then
      error(format("'%s:' no '%s' function", name, "add"), 3)
    end
    if type(mapping.delete) ~= "function" then
      error(format("'%s:' no '%s' function", name, "delete"), 3)
    end
  else
    if objtype.access ~= "readOnly" then
      error(format("'%s%s': 'access' should be 'readOnly' or 'readWrite'", name, ""), 3)
    end
  end
  for pname, ptype in pairs(objtype.parameters) do
    local full_name = name..pname
    if type(pname) ~= "string" then
      error(format("'%s': parameter table is invalid", name), 3)
    end
    -- Generate a warning if the parameter is a vendor extension and there's no description.
    if match(full_name, "%.X_") and not ptype.description then
      logger:warning("'%s': no description", full_name)
    end
    if type(ptype) ~= "table" then
      error(format("'%s': '%s' not a %s", name, pname, "table"), 3)
    end
    -- We remove 'ptype.description' in memory because it's not needed at runtime.
    ptype.description = nil
    if not default_hidden_values[ptype.type]  then
      error(format("'%s': invalid type '%s'", full_name, ptype.type or "nil"), 3)
    end
    if ptype.access == "readWrite" then
      if pname ~= objtype.aliasParameter then
        local set = mapping.set
        local type_set = type(set)
        if type_set ~= "function" and (type_set ~= "table" or type(set[pname]) ~= "function") then
          error(format("'%s': no setter", full_name), 3)
        end
      end
    elseif ptype.access ~= "readOnly" then
      error(format("'%s': 'access' should be 'readOnly' or 'readWrite'", full_name), 3)
    end
    local type_default = type(ptype.default)
    if type_default ~= "nil" and type_default ~= "string" then
      error(format("'%s': '%s' not a %s", full_name, "default", "string"), 3)
    end
    local get = mapping.get
    local type_get = type(get)
    if pname ~= objtype.aliasParameter then
      if type_get ~= "function" and
         (type_get ~= "table" or (type(get[pname]) ~= "function"
           and type(get[pname]) ~= "string")) then
        error(format("'%s': no getter", full_name), 3)
      end
    end
    -- If a parameter path is ignored, remove the parameter from the object type.
    if is_ignored(full_name, ignore_patterns, vendor_patterns) then
      objtype.parameters[pname] = nil
    end
  end
  local getall = mapping.getall
  if getall and type(getall)~='function' then
    error(format("getall for %s must be a function if supplied", name), 3)
  end
  return true
end

-- check if all fields of 't' are also in 'u'
local function is_subset(t, u)
  for k, v in pairs(t) do
    if u[k] ~= v then
      return false
    end
  end
  return true
end

-- Count the number of fields in table 't'
local function get_count(t)
  local count = 0
  for _,_ in pairs(t) do
    count = count + 1
  end
  return count
end

-- Metatable for the paramtype_cache. If a lookup occurs of an unknown
-- key, we create a new weak table and return it.
local mt = {}

mt.__index = function(t,key)
  local v = setmetatable({}, {__mode = "v"})
  rawset(t,key,v)
  return v
end

-- Cache of all paramtypes so we can easily iterate over them to
-- check if a new paramtype is the same as one in the cache. The cache
-- contains sub-tables for every size of paramtype it encounters.
-- This cache has weak sub-tables to prevent the cache keeping
-- paramtypes alive when no mappings still refer to it.
local paramtype_cache = setmetatable({}, mt)

local function memoize_paramtype(paramtype)
  local count = get_count(paramtype)
  local cache = paramtype_cache[count]
  for _, cached in pairs(cache) do
    if is_subset(cached, paramtype) then
      return cached
    end
  end
  cache[#cache + 1] = paramtype
  return paramtype
end

--- A special function which will memoize the parametertype definitions
-- These are notoriously repetitive, this halves the memory used for parametertypes.
local function memoize_paramtypes(mapping)
  local paramtypes = mapping.parameters

  for name, paramtype in pairs(paramtypes) do
    paramtypes[name] = memoize_paramtype(paramtype)
  end
end

local function create_map_env(store, commitapply, ignore_patterns, vendor_patterns, unhide_patterns)
  -- The environment available to a mapping.
  -- All these functions can throw an error.
  local function register(mapping)
    local ok, reason = validate_mapping(mapping, ignore_patterns, vendor_patterns)
    if ok then
      hidden_mapping(mapping, unhide_patterns)
      alias_mapping(store, mapping)
      memoize_paramtypes(mapping.objectType)
      store:add_mapping(mapping)
    else
      logger:info(reason)
    end
  end
  local map_env = {
    commitapply = commitapply,
    register = register,
    resolve = function(typepath, key)
        return xref.resolve(store, typepath, key)
    end,
    tokey = function(objectpath, ...)
        return xref.tokey(store, objectpath, ...)
    end,
    mapper = function(name)
      local mapper = require("transformer.mapper." .. name)
      -- When a function of the mapper is called we want to access
      -- the commitapply context in that function. To be able to do
      -- that the mapper function must have the environment that is
      -- used on the mapping file chunk.
      local fenv = getfenv(2)
      for _, f in pairs(mapper) do
        if type(f) == "function" then
          setfenv(f, fenv)
        end
      end
      return mapper
    end,
    eventsource = function(name)
      local evsrc = require("transformer.eventsource." .. name)
      evsrc.set_store(store)
      return evsrc
    end,
    query_keys = function(mapping, level)
      return store.persistency:query_keys(mapping.tp_id, level)
    end
  }
  -- in your map you can access everything but you're
  -- not allowed to create new global variables
  setmetatable(map_env, {
    __index = _G,
    __newindex = function()
        error("global variables are evil", 2)
    end
  })
  return map_env
end

-- Load the map pointed to by 'file' using the provided environment.
local function load_map(map_env, file)
  local mapping, errmsg = loadfile(file)
  if not mapping then
    -- file not found or syntax error in map
    return nil, errmsg
  end
  setfenv(mapping, map_env)
  local rc, errormsg = pcall(mapping)
  if not rc then
    -- map didn't load; probably because it didn't validate
    return nil, errormsg
  end
  logger:info("loaded %s", file)
  return true
end

-- the mapping get function for a numEntries parameter
local function get_child_count(mapping, paramname, ...)
    local numEntries = mapping['@@_numEntries']
    local child = numEntries[paramname]
    if child then
        local rc, entries, errmsg = xpcall(child.entries, traceback, child, ...)
        if not rc then
            logger:error("entries() threw an error : %s", entries)
        elseif not entries then
            logger:error("entries() failed: %s", errmsg or "<no error msg>")
        else
            return tostring(#entries)
        end
    else
        logger:warning("no entries for %s.%s", mapping.objectType.name, paramname)
    end
    return '0'
end

-- fixup the NumberOfEntries parameters
-- loop over all mapping and add their numEntriesParameter (if any) to their
-- parent.
local function fixupNumberOfEntries(store)
    local numEntriesType = memoize_paramtype{
        access = "readOnly";
        type = "unsignedInt";
        single = true; --to prevent getting it through getall
    }
    for _, mapping in ipairs(store.mappings) do
        local pne = mapping.objectType.numEntriesParameter
        if pne then
            -- there is a numEntriesParameter
            -- get the parent
            local parent = store:parent(mapping)
            if parent then
                -- make sure the parameter exists
                if not parent.objectType.parameters[pne] then
                    parent.objectType.parameters[pne] = numEntriesType
                end
                -- add it to the list of numEntries parameters in the parent
                -- this info is used in the getter function
                local numEntries = parent['@@_numEntries']
                if not numEntries then
                    numEntries = {}
                    parent['@@_numEntries'] = numEntries
                end
                numEntries[pne] = mapping

                maphelper.wrap_get(parent)
                parent.get[pne] = get_child_count
            end
        end
    end
end

-- Load all the maps on the specified path recursively and store them in
-- the provided map environment.
local function load_maps_recursively(map_env, mappath)
  -- if 'mappath' points to a file then load that file
  if lfs.attributes(mappath, 'mode') == 'file' then
    -- only consider files with the '.map' extension
    if find(mappath, "%.map$") then
      local rc, errormsg = load_map(map_env, mappath)
      -- currently we just ignore maps that fail to load
      if not rc then
        logger:error("%s ignored (%s)", mappath, errormsg)
      end
    end
  -- if 'mappath' points to a directory load it recursively
  elseif lfs.attributes(mappath, 'mode') == 'directory' then
    for file in lfs.dir(mappath) do
      if file ~= "." and file ~= ".." then
        load_maps_recursively(map_env, mappath.."/"..file)
      end
    end
  end
end

local M = {}

-- Load all the maps in 'mappath' and store them in 'store'.
-- @param store The typestore in which to add loaded mappings.
-- @param commitapply The commit & apply context to use in your mappings or
--                    mappers. See the commit & apply documentation.
-- @param mappath The location where to read the maps from. It can be one file
--          or a directory with map files. In the latter case it will only
--          load files ending with ".map".
-- @param ignore_patterns A table of datamodel patterns that need to be ignored by Transformer.
-- @param vendor_patterns A table of vendor extension patterns that need to be allowed by Transformer.
-- @param unhide_patterns A table of datamodel patterns that must not be hidden by Transformer.
-- @return 'true' if all went well and nil + error message otherwise
function M.load_all_maps(store, commitapply, mappath, ignore_patterns, vendor_patterns, unhide_patterns)
  local map_env = create_map_env(store, commitapply, ignore_patterns, vendor_patterns, unhide_patterns)
  -- a single mapping file is provided
  store.persistency:startTransaction()
  if lfs.attributes(mappath, 'mode') == 'file' then
    local rc, errmsg = load_map(map_env, mappath)
    if not rc then
      return nil, errmsg
    end
  -- a directory with mapping files is provided
  else
    load_maps_recursively(map_env, mappath)
  end
  fixupNumberOfEntries(store)
  store.persistency:commitTransaction()
  return true
end

return M
