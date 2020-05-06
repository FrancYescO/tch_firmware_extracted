local error, type, next, pairs, tonumber, tostring =
      error, type, next, pairs, tonumber, tostring
local format = string.format
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

local function create_binding(mapping, parentkey)
  local sectionname
  if not mapping.parent.index_spec then
    sectionname = mapping.binding.sectionname
  elseif mapping.parent.index_spec == "{i}" then
    sectionname = mapping.parent.instances[parentkey]
  else --"@"
    sectionname = parentkey
  end
  local binding = mapping.binding
  binding.sectionname = sectionname
  return binding
end

local function load_elements(mapping, parentkey)
  local binding = create_binding(mapping, parentkey)
  local elements = uci_helper.get_from_uci(binding)
  if type(elements) ~= "table" then
    elements = {}
  end
  mapping.elements[parentkey] = elements
  return elements
end

local function save_elements(mapping, parentkey)
  local binding = create_binding(mapping, parentkey)
  uci_helper.delete_on_uci(binding, mapping.commitapply)
  if #mapping.elements[parentkey] > 0 then
    uci_helper.set_on_uci(binding, mapping.elements[parentkey], mapping.commitapply)
  end
  mapping.transaction[binding.sectionname] = true
end

--- A generic get function for a uci list object.
-- @param mapping The mapping on which the get function needs to be executed.
--                This mapping should contain uci binding.
-- @param paramname The name of the parameter we need to retrieve (= "value").
-- @param key The key that uniquely identifies the list element specified by
--            the given mapping (= index).
local function get(mapping, _, key, parentkey)
  return mapping.elements[parentkey or 0][index_extraction(key)]
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
  mapping.elements[parentkey][index_extraction(key)] = value
  save_elements(mapping, parentkey)
end

--- A generic add function for a uci list object.
-- @param mapping The mapping on which the add function needs to be executed.
--                This mapping should contain uci binding.
local function add(mapping, name, parentkey)
  if name then
    error("Add with given name is not supported.")
  end
  parentkey = parentkey or 0
  local elements = load_elements(mapping, parentkey)
  elements[#elements + 1] = ""
  save_elements(mapping, parentkey)
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
  local elements = mapping.elements[parentkey]
  if idx > #elements then
    return nil, "The object that needs to be deleted does not exist"
  end
  remove(elements, idx)
  save_elements(mapping, parentkey)
  return true
end

--- A deleteall function to remove all elements in a uci list.
-- @param mapping The mapping on which the delete function needs to be executed.
--                This mapping should contain uci binding.
-- @param parentkey The key that uniquely identifies the list parent.
local function deleteall(mapping, parentkey)
  parentkey = parentkey or 0
  mapping.elements[parentkey] = {}
  save_elements(mapping, parentkey)
  return true
end

--- A generic entries function for a uci list object.
-- @param mapping The mapping on which the entries function needs to be executed
--                This mapping should contain uci binding.
local function entries(mapping, parentkey)
  parentkey = parentkey or 0
  local elements = load_elements(mapping, parentkey)
  local keys = {}
  for i = 1, #elements do
    keys[#keys + 1] = key_generation(i, parentkey)
  end
  return keys
end

--- A generic commit function for a mapping.
local function commit(mapping)
  local result, errmsg
  local binding = mapping.binding
  for sectionname in pairs(mapping.transaction) do
    binding.sectionname = sectionname
    result, errmsg = uci_helper.commit(binding)
    if not result then
      -- uci_helper returns false + error message but
      -- Transformer wants nil + error message
      result = nil
    end
  end
  mapping.transaction = {}
  return result, errmsg
end

--- A genertic revert function for a mapping.
local function revert(mapping)
  local result, errmsg
  local binding = mapping.binding
  for sectionname in pairs(mapping.transaction) do
    binding.sectionname = sectionname
    result, errmsg = uci_helper.revert(binding)
    if not result then
      -- uci_helper returns false + error message but
      -- Transformer wants nil + error message
      result = nil
    end
  end
  mapping.transaction = {}
  return result, errmsg
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
    transaction = {},
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
    elements = {}
  }
end

return M
