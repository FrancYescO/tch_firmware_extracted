--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local error, type, next, pairs, tonumber, tostring =
      error, type, next, pairs, tonumber, tostring
local format, match = string.format, string.match
local remove = table.remove

---
-- This mapper will implement a list mapper against a uci backend.
-- @module transformer.mapper.ucilist
local M = {}

-- A helper object to communicate with uci
local uci_helper = require("transformer.mapper.ucihelper")

--- Helper function to extract the index number from a given key.
-- @param #string key The key from which to extract the index number. If this helper
--                    has a parent, the given key will contain a parent reference
--                    which should be stripped off.
-- @return #number The index number that is contained in the key.
local function index_extraction(key)
  return tonumber(key:match("|(%d+)$"))
end

--- Helper function to generate a key given an index number and a parent reference.
-- @param #number index The index number used in the key generation.
-- @param #string or #number parentkey The key of the parent.
-- @return #table A table is returned with as first element the display name to be used
--                and as second element the actual key to be used.
local function key_generation(index, parentkey)
  local displayname = tostring(index)
  local key = parentkey.."|"..displayname
  return { displayname, key }
end

local function get_sectionname(mapping, parentkey)
  local sectionname
  if not mapping.parent.index_spec then
    sectionname = mapping.binding.sectionname
  elseif mapping.parent.index_spec == "{i}" then
    sectionname = mapping.parent.instances[parentkey]
  else --"@"
    --When unnamed UCI sections are mapped (in uci_1to1.lua) as named, the generated key
    --is "<sectiontype>[<index>]". This can be used as section name when the extended
    --UCI syntax is used, provided it's prefixed with the '@' symbol.
    if match(parentkey, ("^".. mapping.binding.sectiontype .. "%[%d+%]$")) then
      sectionname = "@"..parentkey
      mapping.binding.extended = true
    else
      sectionname = parentkey
    end
  end
  return sectionname
end

local function get_elements(mapping, parentkey)
  local binding = mapping.binding
  binding.sectionname = get_sectionname(mapping, parentkey)
  local elements = uci_helper.get_from_uci(binding)
  if type(elements) ~= "table" then
    elements = {}
  end
  return elements
end

local function save_elements(mapping, parentkey, elements)
  local binding = mapping.binding
  binding.sectionname = get_sectionname(mapping, parentkey)
  if #elements > 0 then
    uci_helper.set_on_uci(binding, elements, mapping.commitapply)
  else
    uci_helper.delete_on_uci(binding, mapping.commitapply)
  end
  mapping.transaction = true
end

--- Helper function to execute the appropriate transaction function.
-- @param fn The function to execute to complete the transaction (commit or revert).
-- @param mapping The mapping on which the transaction function needs to be executed.
--                This mapping should contain uci binding.
-- @return nil + nil or nil + error message
local function do_transaction(fn, mapping)
  local result, errmsg
  if mapping.transaction then
    result, errmsg = fn(mapping.binding)
    if not result then
      -- uci_helper returns false + error message but
      -- Transformer wants nil + error message
      result = nil
    end
  end
  mapping.transaction = false
  return result, errmsg
end

--- A generic get function for a uci list object.
-- @param mapping The mapping on which the get function needs to be executed.
--                This mapping should contain uci binding.
-- @param paramname The name of the parameter we need to retrieve (= "value").
-- @param key The key that uniquely identifies the list element specified by
--            the given mapping (= index).
local function get(mapping, _, key, parentkey)
  parentkey = parentkey or 0
  local elements = get_elements(mapping, parentkey)
  return elements[index_extraction(key)]
end

--- A generic set function for a uci list object.
-- @param mapping The mapping on which the set function needs to be executed.
--                This mapping should contain uci binding.
-- @param paramname The name of the parameter that needs to be set (= "value").
-- @param value The new value for the given parameter.
-- @param key The key that uniquely identifies the list element specified by
--            the given mapping (= index).
local function set(mapping, _, value, key, parentkey)
  parentkey = parentkey or 0
  local elements = get_elements(mapping, parentkey)
  elements[index_extraction(key)] = value
  save_elements(mapping, parentkey, elements)
end

--- A generic add function for a uci list object.
-- @param mapping The mapping on which the add function needs to be executed.
--                This mapping should contain uci binding.
local function add(mapping, name, parentkey)
  if name then
    error("Add with given name is not supported.")
  end
  parentkey = parentkey or 0
  local elements = get_elements(mapping, parentkey)
  elements[#elements + 1] = ""
  save_elements(mapping, parentkey, elements)
  return key_generation(#elements, parentkey)
end

--- A generic delete function for a uci list object.
-- @param mapping The mapping on which the delete function needs to be executed.
--                This mapping should contain uci binding.
-- @param key The key that uniquely identifies the list element specified by
--            the given mapping (= index).
local function delete(mapping, key, parentkey)
  parentkey = parentkey or 0
  local idx = index_extraction(key)
  local elements = get_elements(mapping, parentkey)
  if idx > #elements then
    return nil, "The object that needs to be deleted does not exist"
  end
  remove(elements, idx)
  save_elements(mapping, parentkey, elements)
  return true
end

--- A deleteall function to remove all elements in a uci list.
-- @param mapping The mapping on which the delete function needs to be executed.
--                This mapping should contain uci binding.
-- @param parentkey The key that uniquely identifies the list parent.
local function deleteall(mapping, parentkey)
  parentkey = parentkey or 0
  save_elements(mapping, parentkey, {})
  return true
end

--- A generic entries function for a uci list object.
-- @param mapping The mapping on which the entries function needs to be executed
--                This mapping should contain uci binding.
local function entries(mapping, parentkey)
  parentkey = parentkey or 0
  local elements = get_elements(mapping, parentkey)
  local keys = {}
  for i = 1, #elements do
    keys[#keys + 1] = key_generation(i, parentkey)
  end
  return keys
end

--- A generic commit function for a mapping.
local function commit(mapping)
  return do_transaction(uci_helper.commit, mapping)
end

--- A generic revert function for a mapping.
local function revert(mapping)
  return do_transaction(uci_helper.revert, mapping)
end

---
-- @function [parent=#transformer.mapper.ucilist] createListMap
-- @param #table parentmapping
-- @param #string config
-- @param #string section
-- @param #string type
-- @param #string list
function M.createListMap(parentmapping, config, section, type, list)
  local name
  if not parentmapping.index_spec then
    name = format("uci.%s.%s.%s.@.", config, section, list)
  else
    name = format("uci.%s.%s.%s.%s.@.", config, type, parentmapping.index_spec, list)
  end
  return {
    objectType = {
      name = name,
      access = "readWrite",
      minEntries = 0,
      maxEntries = math.huge,
      parameters = {
        value = {
          access = "readWrite",
          type = "string"
        }
      }
    },
    parent = parentmapping,
    transaction = false,
    binding = {
      config = config,
      sectionname = section,
      sectiontype = type,
      option = list
    },
    commitapply = commitapply,
    get = get,
    set = set,
    add = add,
    delete = delete,
    deleteall = deleteall,
    entries = entries,
    commit = commit,
    revert = revert,
  }
end

return M
