--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

---
-- A multiroot mapping helper.
--
-- Some parts of the datamodel can be reused between datamodels (eg. Service objects, ...)
-- and even within the same datamodel (Identical object definitions, such as WLANConfiguration.{i}.
-- objects under InternetGatewayDevice.LANDevice.{i}. and InternetGatewayDevice.LANInterfaces.).
-- This mapping helper allows for easy duplication of mappings. All functions (get/set/add/...)
-- are shared between the mappings, only the objectType definition is altered.
--
-- @module transformer.mapper.multiroot
-- @usage
-- local Multi_Service_ = {
--   objectType = {
--     name = "#ROOT.Service.",
--     ...
--   }
-- }
-- ...
-- # Instead of the usual register(Multi_Service_)
-- local duplicator = mapper("multiroot").duplicate
-- local duplicates = duplicator(Multi_Service_, "#ROOT", {"InternetGatewayDevice", "Device"})
-- for _, dupli in ipairs(duplicates) do
--   register(dupli)
-- end

local type, setmetatable, getmetatable = type, setmetatable, getmetatable
local pairs, ipairs = pairs, ipairs

local M = {}

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--- Duplicate a given mapping and replace all occurrences of the given pattern by a replacement.
-- A shallow clone is made of the original mapping for each replacement given. Only for the
-- objectType do we create a deep copy. Finally the given pattern is substituted by the replacement
-- in objectType name.
-- @tparam table mapping A table representation of the mapping that needs to be duplicated.
-- @string pattern The pattern present in the mapping's objectType name that needs to be replaced during duplication.
-- @tparam table replacements An array of strings that need to replace the given pattern in the duplication.
-- @treturn table An array containing all the duplicated mappings.
function M.duplicate(mapping, pattern, replacements)
  local result = {}
  for _, repl in ipairs(replacements) do
    local newmapping = {}
    for k,v in pairs(mapping) do
      if k == "objectType" then
        newmapping[k] = deepcopy(v)
        newmapping[k].name = newmapping[k].name:gsub(pattern, repl)
      else
        newmapping[k]=v
      end
    end
    result[#result + 1] = newmapping
  end
  return result
end

return M
