--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

---
-- This mapper allows you to easily map certain datamodel parameters of a
-- single instance object type to UCI.
-- The binding information you need to provide in the connect() call specifies
-- for each parameter how to map it to UCI. You do not have to provide binding
-- information for every parameter in the object type. You can let this mapper
-- handle only those parameters that have a direct mapping to UCI and you can
-- provide specific getters and setters for parameters that need more logic.
-- However, this requires that the 'get' field of the mapping table is a table,
-- it can not be a generic function that handles all parameters.
-- The binding information looks like follows:
--   {
--     Name = {
--       config = "foo", sectionname = "config", option = "name", default = "none"
--     },
--     LastUse = {
--       uci_config = { config = "foo", sectionname = "config", option = "lastuse" },
--       get = function(uci_value)
--         return converted_value
--       end,
--       set = function(new_value)
--         return converted_new_value
--       end
--     }
--   }
-- So for each parameter you can either provide only the UCI mapping information
-- with an optional default value (used when UCI doesn't have the parameter) or
-- you provide the mapping information and conversion functions to convert the
-- value between the datamodel and UCI. Example of the latter could be to
-- convert between a Unix timestamp (seconds since Epoch) in UCI and a
-- dateTime string in the datamodel.

local assert, error, type, pairs = assert, error, type, pairs
local find, format = string.find, string.format

local logger = require("tch.logger")

---
-- @module transformer.mapper.simpleuci
local M = {}

-- A helper object to communicate with uci
local uci_helper = require("transformer.mapper.ucihelper") --transformer.mapper.ucihelper#transformer.mapper.ucihelper
local get_from_uci = uci_helper.get_from_uci
local set_on_uci = uci_helper.set_on_uci
local commit = uci_helper.commit

-- A generic get function for a parameter of a single instance UCI object.
-- @param mapping The mapping on which the get function needs to be executed.
--                This mapping should contain UCI bindings.
-- @param paramname The name of the parameter we need to retrieve.
-- @return The value of the parameter as retrieved from UCI, possibly
--         converted using a conversion function supplied in the binding table.
local function getter(mapping, paramname)
  local binding = mapping.binding[paramname]
  if binding.get then
    return binding.get(get_from_uci(binding.uci_config))
  end
  return get_from_uci(binding)
end

-- A generic set function for a parameter of a single instance UCI object.
-- If a conversion function is supplied in the binding table then the new value
-- is first passed to this function before setting it on UCI.
-- Commit & Apply is used if available. 
-- @param mapping The mapping on which the set function needs to be executed.
--                This mapping should contain UCI bindings.
-- @param paramname The name of the parameter that needs to be set.
-- @param value The new value for the given parameter.
local function setter(mapping, paramname, value)
  local binding = mapping.binding[paramname]
  if binding.set then
    value = binding.set(value)
    binding = binding.uci_config
  end
  set_on_uci(binding, value, mapping.commitapply)
  local transaction = mapping.transaction
  transaction[#transaction + 1] = binding
end

--- A generic commit function for a mapping.
local function commit(mapping)
  logger:debug("simpleuci: committing")
  local result = true
  for _,binding in pairs(mapping.transaction) do
    if not uci_helper.commit(binding) then
      result = false
    end
  end
  mapping.transaction = {}
  return result
end

--- A genertic revert function for a mapping.
local function revert(mapping)
  logger:debug("simpleuci: reverting")
  local result = true
  for _,binding in pairs(mapping.transaction) do
    if not uci_helper.revert(binding) then
      result = false
    end
  end
  mapping.transaction = {}
  return result
end

-- Validate if the given UCI bindings are well formed.
local function validate_uci_bindings(mapping, bindings)
  if type(bindings) ~= "table" then
    error("binding info is not a table", 3)
  end
  if next(bindings) == nil then
    error("binding info is empty", 3)
  end
  local params = mapping.objectType.parameters
  for paramname,v in pairs(bindings) do
    if type(paramname) ~= "string" then
      error("keys of binding table should be strings", 3)
    end
    if not params[paramname] then
      error("binding for unknown parameter " .. paramname, 3)
    end
    if type(v) ~= "table" then
      error("binding for " .. paramname .. " is not a table", 3)
    end
    if not v.config and not (v.uci_config and v.uci_config.config) then
      error(format("no '%s' entry in binding for %s", "config", paramname), 3)
    end
    if not v.sectionname and not (v.uci_config and v.uci_config.sectionname) then
      error(format("no '%s' entry in binding for %s", "sectionname", paramname), 3)
    end
    if not v.option and not (v.uci_config and v.uci_config.option) then
      error(format("no '%s' entry in binding for %s", "option", paramname), 3)
    end
  end
end

-- Insert the necessary get and set functions in the mapping table for
-- those parameters for which we have UCI binding information.
-- Note that the get and set fields in the mapping table must be either nil
-- or a table. A function is not supported.
local function connect(mapping, binding)
  local get = mapping.get
  if not get then
    get = {}
    mapping.get = get
  end
  assert(type(get) == "table", "getter must be a table", 3)
  local params = mapping.objectType.parameters
  for param in pairs(binding) do
    get[param] = getter
    if params[param].access == "readWrite" then
      local set = mapping.set
      if not set then
        set = {}
        mapping.set = set
      end
      assert(type(set) == "table", "setter must be a table", 3)
      set[param] = setter
    end
  end
  local m_commit = mapping.commit
  if not m_commit then
    mapping.commit = commit
  else
    mapping.commit = function(m)
      m_commit(m)
      commit(m)
    end
  end
  local m_revert = mapping.revert
  if not m_revert then
    mapping.revert = revert
  else
    mapping.revert = function(m)
      m_revert(m)
      revert(m)
    end
  end
end

--- Connect the simple UCI mapper with its mapping.
-- This function expects a table with one or more UCI binding items.
-- Note that this function is executed in the context of
-- loading a mapping file. In that environment there's a
-- global 'commitapply' available.
-- @function [parent=#transformer.mapper.simpleuci] connect
-- @param mapping the object mapping
-- @param binding A table containing the actual mappings to uci. See
--                the description at the top of this file for more info.
function M.connect(mapping, binding)
  local objtype = mapping.objectType
  assert(objtype, "no object type")
  assert(type(objtype.name) == "string", "no valid object type name")
  assert(type(objtype.parameters) == "table", "no valid parameter table")
  if nil ~= find(objtype.name, '%.{i}%.$') then
    error("this mapper is for single instance object types", 2)
  end
  validate_uci_bindings(mapping, binding)
  if not mapping.transaction then
    mapping.transaction = {}
  end
  mapping.binding = binding
  mapping.commitapply = commitapply
  connect(mapping, binding)
end

return M
