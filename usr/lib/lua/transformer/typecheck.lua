--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

-- This module implements type checking for parameters

local floor = math.floor
local error, tonumber, tostring, type, pairs =
      error, tonumber, tostring, type, pairs
local format = string.format

local logger = require("transformer.logger")
local fault = require 'transformer.fault'

local M = {}

--- placeholder for type that are not yet implemented but should be supported
local function notImplemented(value, paramInfo)
  logger:notice("%s typecheck not implemented (yet)", paramInfo.type)
  return value
end

--- Remove the min and max fields from the given paramter info table.
-- Returns a copy of the given table with the min and max fields removed.
local function removeMinMax(paramInfo)
  local result = {}
  for k,v in pairs(paramInfo) do
    if k ~= "min" and k ~= "max" then
      result[k] = v
    end
  end
  return result
end

--- Retrieves the root node of the given path.
local function retrieveRoot(path)
  return path:match("^[^.]+%.")
end

--- handle a single string.
-- The type of the first argument should already be verified
-- to be a string before calling this method.
-- return value
local function single_string_value(value, paramInfo, fullPath)
  if paramInfo["min"] then
    local minLength = tonumber(paramInfo["min"])
    if minLength and minLength > #value then
      fault.InvalidValue("string '%s' is too short (minimum %d)", value, minLength)
    end
  end
  if paramInfo["max"] then
    local maxLength = tonumber(paramInfo["max"])
    if maxLength and maxLength < #value then
      fault.InvalidValue("string '%s' is too long (maximum %d)", value, maxLength)
    end
  end
  if paramInfo["enumeration"] then
    local found = false
    for _,entry in pairs(paramInfo["enumeration"]) do
      if entry == value then
        found = true
      end
    end
    if not found then
      fault.InvalidValue("string '%s' is not a valid entry of the enumeration", value)
    end
  end
  if paramInfo["pathRef"] and value ~= "" then
    if retrieveRoot(value) ~= retrieveRoot(fullPath) then
      fault.InvalidValue("string '%s' is not a valid path reference", value)
    end
    if paramInfo["targetParent"] then
      local typepath = value:gsub("%.%d+%.", ".{i}.")
      typepath = typepath:gsub("%.%d+$", ".{i}.")
      if not typepath:match("^"..paramInfo["targetParent"]) then
        fault.InvalidValue("string '%s' does not reference a correct path %s", value, paramInfo["targetParent"])
      end
    end
    -- Note that the actual path is not checked for existence. This is because
    -- some references are weak and do not have to exist when they are created.
  end
  return value
end

local function single_hexBinary_value(value, paramInfo, fullPath)
  -- string may contain only hex characters
  if value:match('%X+') then
    fault.InvalidValue("hexBinary '%s' is not valid, contains non hex characters", value)
  end
  local plen = #value
  -- length must be even
  if plen%2 ~= 0 then
    fault.InvalidValue("hexBinary '%s' is not a valid, length not even", value)
  end
  if paramInfo.min then
    -- min is the number of actual bytes, the length in hexBinary is twice that value
    local minLength = tonumber(paramInfo.min)*2
    if plen<minLength then
      fault.InvalidValue("hexBinary '%s' is too short (minimum=%d)", value, minLength)
    end
  end
  if paramInfo.max then
    -- max is the number of actual bytes, the length in hexBinary is twice that value
    local maxLength = tonumber(paramInfo.max)*2
    if maxLength<plen then
      fault.InvalidValue("hexBinary '%s' is too long (maximum=%d)", value, maxLength)
    end
  end
  return value
end

local STR_FALSE = '0'
local STR_TRUE = '1'
local bool_values = {
  [false] = STR_FALSE;
  ['0'] = STR_FALSE;
  ['false'] = STR_FALSE;
  [0] = STR_FALSE;

  [true] = STR_TRUE;
  ['1'] = STR_TRUE;
  ['true'] = STR_TRUE;
  [1] = STR_TRUE;
}
--- handle boolean values
local function boolean_value(value, paramInfo)
  local v = bool_values[value]
  if not v then
    fault.InvalidType("'%s' is not a valid boolean", tostring(value))
  end
  return v
end

--- handle a single unsigned value.
-- return value
local function single_unsigned_value(value, paramInfo)
  local n = tonumber(value)
  if not n or floor(n)~=n or 0>n then
    fault.InvalidType("'%s' is not a valid unsigned value", tostring(value))
  end
  if paramInfo.type == "unsignedInt" and n > 4294967295 then
    fault.InvalidValue("'%s' is out of unsignedInt range", tostring(value))
  end
  if paramInfo["range"] and type(paramInfo["range"]) == 'table' then
    local inRange = false
    local message = format("unsigned value '%d' not in range ",n)
    -- Multiple ranges are possible, find one that is correct
    for _,v in pairs(paramInfo["range"]) do
      local correct = true
      local rangeMessage = "["
      if v["min"] then
        local minLength = tonumber(v["min"])
        if minLength and minLength > n then
          correct = false
        end
        rangeMessage = rangeMessage..minLength
      end
      rangeMessage = rangeMessage..","
      if v["max"] then
        local maxLength = tonumber(v["max"])
        if maxLength and maxLength < n then
          correct = false
        end
        rangeMessage = rangeMessage..maxLength
      end
      rangeMessage = rangeMessage.."]"
      inRange = inRange or correct
      message = message..rangeMessage
    end
    if not inRange then
      fault.InvalidValue(message)
    end
  end
  return tostring(n)
end

--- handle a single integer value.
-- return value
local function single_integer_value(value, paramInfo)
  local n = tonumber(value)
  if not n or floor(n)~=n then
    fault.InvalidType("'%s' is not a valid integer", tostring(value))
  end
  if paramInfo["range"] and type(paramInfo["range"]) == 'table' then
    local inRange = false
    local message = format("integer value '%d' not in range ",n)
    -- Multiple ranges are possible, find one that is correct
    for _,v in pairs(paramInfo["range"]) do
      local correct = true
      local rangeMessage = "["
      if v["min"] then
        local minLength = tonumber(v["min"])
        if minLength and minLength > n then
          correct = false
        end
        rangeMessage = rangeMessage..minLength
      end
      rangeMessage = rangeMessage..","
      if v["max"] then
        local maxLength = tonumber(v["max"])
        if maxLength and maxLength < n then
          correct = false
        end
        rangeMessage = rangeMessage..maxLength
      end
      rangeMessage = rangeMessage.."]"
      inRange = inRange or correct
      message = message..rangeMessage
    end
    if not inRange then
      fault.InvalidValue(message)
    end
  end
  return tostring(n)
end

local singlemap = {
  string = single_string_value,
  unsigned_value = single_unsigned_value,
  integer_value = single_integer_value,
  hexBinary = single_hexBinary_value
}

--- handle a single value
-- return the value
local function single_value(value, paramInfo, paramType, fullPath)
  local single_checker = singlemap[paramType]
  if single_checker then
    return single_checker(value, paramInfo, fullPath)
  end
  fault.InvalidType("type %s is unsupported", paramType)
end

--- handle a list of values (Only comma-separated allowed)
-- return the list
local function list_value(list, paramInfo, paramType, fullPath)
  local result = ""
  if type(list)=='string' then
    -- The min and max parameter attributes refer to the list and not the single
    -- values. Remove from the parameter info table before passing it on.
    if paramInfo["min"] then
      local minLength = tonumber(paramInfo["min"])
      if minLength and minLength > #list then
        fault.InvalidValue("%s list '%s' is too short (minimum %d)", paramType, list, minLength)
      end
    end
    if paramInfo["max"] then
      local maxLength = tonumber(paramInfo["max"])
      if maxLength and maxLength < #list then
        fault.InvalidValue("%s list '%s' is too long (maximum %d)", paramType, list, maxLength)
      end
    end
    local entries = 0
    local subParamInfo = removeMinMax(paramInfo)
    for single in list:gmatch("[^,]+") do
      if result ~= "" then
        result = result .. ","
      end
      result = result .. single_value(single, subParamInfo, paramType, fullPath)
      entries = entries + 1
    end
    subParamInfo = nil
    if paramInfo["maxItems"] then
      local maxItems = tonumber(paramInfo["maxItems"])
      if maxItems and maxItems < entries then
        fault.InvalidValue("%s list '%s' has too many elements (maximum %d)", paramType, list, maxItems)
      end
    end
    if paramInfo["minItems"] then
      local minItems = tonumber(paramInfo["minItems"])
      if minItems and minItems > entries then
        fault.InvalidValue("%s list '%s' has too few elements (minimum %d)", paramType, list, minItems)
      end
    end
    return result
  end
  fault.InvalidType("'%s' is not a valid %s list", tostring(list), paramType)
end

local function any_value(value, paramInfo, paramType, fullPath)
  if paramInfo["list"] then
    return list_value(value, paramInfo, paramType, fullPath)
  else
    return single_value(value, paramInfo, paramType, fullPath)
  end
end

--- handle string values
-- return value
local function string_value(value, paramInfo, fullPath)
  if type(value)=='string' then
    return any_value(value, paramInfo, "string", fullPath)
  end
  fault.InvalidType("'%s' is not valid string", tostring(value))
end

--- handle unsigned values
-- return value
local function unsigned_value(value, paramInfo)
  return any_value(value, paramInfo, "unsigned_value")
end

--- handle integer values
-- return value
local function integer_value(value, paramInfo)
  return any_value(value, paramInfo, "integer_value")
end

--- handle hexBinary value
-- return value
local function hexBinary_value(value, paramInfo, fullPath)
  if type(value)=='string' then
    return any_value(value, paramInfo, "hexBinary", fullPath)
  end
  fault.InvalidType("'%s' is not valid hexBinary", tostring(value))
end

local typemap = {
  string = string_value;
  base64 = notImplemented;
  boolean = boolean_value;
  dateTime = notImplemented;
  hexBinary = hexBinary_value;
  int = integer_value;
  long = integer_value;
  unsignedInt = unsigned_value;
  unsignedLong = unsigned_value;
  password = string_value;
}

--- Check the validity of the value and convert it to its simplest form
-- @param value the string representing the value
-- @param paramInfo the parameter info from the objectType
-- @param fullPath The full path of the parameter
-- @return the simplest form of the value as a string.
--    throws an error if something's amiss.
-- What the simplest form of the value is, is determined by the type.
-- e.g. for an integer '1', '+1 ', ' +1  ' are all valid and the simplest form
-- is '1' so that will be returned.
function M.checkValue(value, paramInfo, fullPath)
  local typename = paramInfo.type
  local checker = typemap[typename]
  if checker then
    return checker(value, paramInfo, fullPath)
  end
  fault.InvalidType("type %s is unsupported", typename)
end

return M
