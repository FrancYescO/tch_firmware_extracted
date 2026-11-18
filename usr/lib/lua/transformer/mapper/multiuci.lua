--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local error, type, next, pairs = error, type, next, pairs
local find = string.find
local pathfinder = require 'transformer.pathfinder' 

---
-- This mapper will implement a multi instance mapper against a uci backend.
local M = {}

-- A helper object to communicate with uci
local uci_helper = require("transformer.mapper.ucihelper") --transformer.mapper.ucihelper#transformer.mapper.ucihelper

--- Load all instances from uci and add their name to a table
-- For {i}-mappings, the table will be indexed by key
local function load_instances(mapping)
  mapping.instances = {}
  local uci_binding = mapping.binding
  local key_generated = false

  local cb
  if (uci_binding.name_based == true) then
    cb = function(t)
      local key
      if t[".anonymous"] then
        key = t[".type"] .. "[" .. t[".index"] .. "]"
      else
        key = t[".name"]
      end
      mapping.instances[key] = t[".name"]
    end
  else
    cb = function(t)
      local key
      if not t["_key"] then
        local binding = {
          config=uci_binding["config"],
          sectionname = t[".name"],
          option="_key"
        }
        key = uci_helper.generate_key_on_uci(binding)
        key_generated = true
      else
        key = t["_key"]
      end
      mapping.instances[key] = t[".name"]
    end
  end
  local binding = {
    config = uci_binding["config"],
    sectionname = uci_binding["type"],
    state = uci_binding["state"]
  }
  local result = uci_helper.foreach_on_uci(binding, cb)
  if key_generated then
    if result then
      uci_helper.commit_keys(binding)
    else
      uci_helper.revert_keys(binding)
    end
  end
end

--- A generic get function for a multi instance uci object.
-- @param mapping The mapping on which the get function needs to be executed.
--                This mapping should contain uci bindings.
-- @param paramname The name of the parameter we need to retrieve.
-- @param parentkey The key that uniquely identifies the parent for the multi instance
--                  object specified by the given mapping.
local function get(mapping, paramname, key)
  if not mapping or mapping == "" or type(mapping) ~= "table" or not mapping.binding then
    error("The given mapping can not be nil, false or empty", 2)
  end
  if not paramname or #paramname == 0 then
    error("The given parameter can not be nil, false or empty", 2)
  end
  if not key or key == "" then
    error("The given key can not be nil, false or empty", 2)
  end
  local uci_name = mapping.instances[key]
  if not uci_name then
    return nil, "The given key "..key.." could not be mapped to uci"
  end
  if not mapping.binding.options or not mapping.binding.options[paramname] then
    return nil, "The given parameter "..paramname.." could not be mapped to uci"
  end

  local binding = {
    config = mapping.binding["config"],
    sectionname = uci_name,
    option = mapping.binding.options[paramname],
    state = mapping.binding["state"],
  }
  return uci_helper.get_from_uci(binding)
end

--- A generic getall function for a multi instance uci object.
-- @param #table mapping The mapping on which the set function needs to be executed.
--               This mapping should contain uci bindings.
-- @param #string parentkey The key that uniquely identifies the parent for the multi instance
--                object specified by the given mapping.
local function getall(mapping, key)
  if not mapping or mapping == "" or type(mapping) ~= "table" or not mapping.binding then
    error("The given mapping can not be nil, false or empty", 2)
  end
  if not key or key == "" then
    error("The given key can not be nil, false or empty", 2)
  end
  local uci_name = mapping.instances[key]
  if not uci_name then
    return nil, "The given key "..key.." could not be mapped to uci"
  end

  local binding = {
    config = mapping.binding["config"],
    sectionname = uci_name,
    state = mapping.binding["state"],
  }
  local result = uci_helper.getall_from_uci(binding)
  local output = {}

  -- Take all the options from the mapping and feed those into the output
  -- for the rest, fill them with a default value since we already fetched
  -- everything and so they won't be there for sure
  for k,v in pairs(mapping.binding.options) do
    if result[v] ~= nil then
      output[k] = result[v]
    else
      output[k] = ""
    end
  end
  return output
end

--- A generic set function for a multi instance uci object.
-- @param mapping The mapping on which the set function needs to be executed.
--                This mapping should contain uci bindings.
-- @param paramname The name of the parameter that needs to be set.
-- @param value The new value for the given parameter.
-- @param parentkey The key that uniquely identifies the parent for the multi instance
--                  object specified by the given mapping.
local function set(mapping, paramname, value, key)
  if not mapping or mapping == "" or type(mapping) ~= "table" or not mapping.binding then
    error("The given mapping can not be nil, false or empty", 2)
  end
  if not paramname or #paramname == 0 then
    error("The given parameter can not be nil, false or empty", 2)
  end
  if not value then
    error("The given value can not be nil or false", 2)
  end
  if not key or key == "" then
    error("The given key can not be nil, false or empty", 2)
  end
  local uci_name = mapping.instances[key]
  if not uci_name then
    return nil, "The given key "..key.." could not be mapped to uci"
  end
  if not mapping.binding.options or not mapping.binding.options[paramname] then
    return nil, "The given parameter "..paramname.." could not be mapped to uci"
  end

  local binding = {
    config = mapping.binding["config"],
    sectionname = uci_name,
    option = mapping.binding.options[paramname],
    sectiontype = mapping.binding["type"]
  }
  uci_helper.set_on_uci(binding, value, mapping.commitapply)
end

local function isPassthrough(mapping)
  return pathfinder.endsWithPassThroughPlaceholder(mapping.objectType.name)
end

--- A generic add function for a multi instance uci object.
-- @param mapping The mapping on which the add function needs to be executed.
--                This mapping should contain uci bindings.
-- @param name (optional) The name to be used for the new object.
local function add(mapping, name)
  -- name is only valid for passthrough mappings, for others it must be ignored.
  if not isPassthrough(mapping) then 
    name = nil
  end
  if name then
    local binding = {
      config = mapping.binding["config"],
      sectionname = name,
    }
    if mapping.instances[name] or uci_helper.get_from_uci(binding) ~= "" then
      return nil, "Object name already in use."
    end  
    uci_helper.set_on_uci(binding, mapping.binding["type"], mapping.commitapply)

    mapping.instances[name] = name
    return name
  else
    local binding = {
      config = mapping.binding["config"],
      sectionname = mapping.binding["type"]
    }
    local result = uci_helper.add_on_uci(binding, mapping.commitapply)
    if not result then
      return nil, "No object could be added for this multi instance object"
    end

    local key = uci_helper.generate_key()
    local keybinding = {
      config=mapping.binding["config"],
      sectionname = result,
      option="_key"
    }
    uci_helper.set_on_uci(keybinding, key)

    mapping.instances[key] = result
    return key
  end
end

--- A generic delete function for a multi instance uci object.
-- @param mapping The mapping on which the delete function needs to be executed.
--                This mapping should contain uci bindings.
-- @param key The key that uniquely identifies the multi instance object to be deleted.
local function delete(mapping, key)
  local uci_name = mapping.instances[key]
  if not uci_name then
    return nil, "The object that needs to be deleted does not exist"
  end

  local binding = {
    config = mapping.binding["config"],
    sectionname = uci_name,
    sectiontype = mapping.binding["type"]
  }
  uci_helper.delete_on_uci(binding, mapping.commitapply)

  mapping.instances[key] = nil
  return true
end

--- A generic commit function for a multi instance uci object.
-- @param mapping The mapping on which the commit function needs to be executed.
local function commit(mapping)
  local binding = {
    config = mapping.binding["config"]
  } --transformer.mapper.ucihelper#binding
  return uci_helper.commit(binding)
end

--- A generic revert function for a multi instance uci object.
-- @param mapping The mapping on which the revert function needs to be executed.
local function revert(mapping)
  local binding = {
    config = mapping.binding["config"]
  } --transformer.mapper.ucihelper#binding
  return uci_helper.revert(binding)
end

--- A generic entries function for a multi instance uci object.
-- @param mapping The mapping on which the entries function needs to be executed.
--                This mapping should contain uci bindings.
local function entries(mapping)
  load_instances(mapping)
  local result = {}
  for k in pairs(mapping.instances) do
    result[#result + 1] = k
  end
  return result
end

--- Validates if the given uci bindings are well formed.
-- Check if the given uci bindings are in a table and that the keys and values are
-- of the type string. Check that entries for keys "config" and "type" are definitely
-- present.
-- @param bindings The uci bindings to be validated.
local function validate_uci_bindings(bindings)
  if not bindings then
    error("The given parameter can not be nil or false", 3)
  end
  if type(bindings) ~= "table" then
    error("The given parameter should be of the type table", 3)
  end
  if next(bindings) == nil then
    error("The given bindings can not be empty", 3)
  end
  local important_keys = 0
  for k,v in pairs(bindings) do
    if type(k) ~= "string" then
      error("The keys of your mapping should be of the type string", 3)
    end
    if type(v) ~= "string" and type(v) ~= "table" then
      error("The values of your mapping should be either of the type string or of the type table", 3)
    end
    -- TODO expand check for config and type. Make sure every parameter
    -- has access to either a local config and type or a global config and type
    if k == "global_config" then
      important_keys = important_keys + 1
    end
    if k == "global_type" then
      important_keys = important_keys + 1
    end
  end
  if important_keys ~= 2 then
    error("One of the important keys is missing", 3)
  end
end

--- Validates if the given uci bindings actually have a corresponding
-- entry in the object type.
-- Check if the given object type contains a table called parameters. For this parameters
-- table, check that the keys are of the type string. Also checks that the given uci_binding
-- table actually contains one or more bindings. Finally, check for the given uci
-- bindings that they have an entry in the given object type.
-- @param object_type The object type for the multi-instance object. This object_type should
--                    not be empty
-- @param uci_binding The uci bindings for the multi-instance object. These bindings
--                    should not be empty.
local function validate_connection(object_type, uci_binding)
  local parameters = {}
  if type(object_type.parameters) ~= "table" then
    error("The parameters of the given object type are not well formed",3)
  end
  for k,v in pairs(object_type.parameters) do
    if type(k) ~= "string" then
      error("The keys of your object type parameters should be of the type string", 3)
    end
    parameters[k]=true
  end
  for k,v in pairs(uci_binding) do
    if k ~= "global_config" and k ~= "global_type" and k ~= "global_state" then
      if parameters[k] == nil then
        error("A given mapping ("..k..") can not be found in the given object type", 3)
      end
    end
  end
end

--- Internal function that expands a given binding to a complete binding
-- A binding can be given in a short hand notation and needs to be expanded
-- to be usable by the functions calling upon the bindings.
-- @param uci_binding A short hand notation of the desired binding
local function expand_connection(uci_binding)
  local binding = {
    config = uci_binding["global_config"],
    type = uci_binding["global_type"],
    state = uci_binding["global_state"],
  }
  uci_binding["global_config"] = nil
  uci_binding["global_type"] = nil
  uci_binding["global_state"] = nil

  binding.options = uci_binding
  return binding
end

--- Connect the multi instance uci mapper with its bindings.
-- This function adds all needed functions for a multi instance object to the
-- given mapper. It expects a table with one or more bindings as its input.
-- Note that this function is executed in the context of
-- loading a mapping file. In that environment there's a
-- global 'commitapply' available.
-- @function [parent=#transformer.mapper.multiuci] connect
-- @param mapping The object mapping to which the functions need to be added.
-- @param binding A table containing the actual bindings to uci.
function M.connect(mapping, binding)
  assert(mapping.objectType, "No object type was found in the given mapping")
  local name = mapping.objectType.name
  assert(type(name)=="string", "The name for the object type in the given mapping should be of type string")
  if nil == find(name, '%.{i}%.$') and nil == find(name, '%.@%.$') then
    error(string.format("use single-instance uci mapper (%s)", name))
  end
  validate_uci_bindings(binding)
  validate_connection(mapping.objectType, binding)
  mapping.instances = {}
  mapping.binding = expand_connection(binding)
  mapping.commitapply = commitapply
  mapping.get = get
  mapping.getall = getall
  mapping.set = set
  mapping.add = add
  mapping.delete = delete
  mapping.entries = entries
  mapping.commit = commit
  mapping.revert = revert

  if (find(mapping.objectType.name, '%.@%.$') ~= nil) then
    mapping.binding.name_based = true
  end
end

return M
