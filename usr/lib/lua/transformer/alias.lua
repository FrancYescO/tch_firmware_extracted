--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local type = type
local setmetatable = setmetatable
local ipairs = ipairs

local nav = require 'transformer.navigation'

local M = {}

local function do_get(db, mapping, _, key)
  local info = db:getAlias(mapping.tp_id, key)
  -- info will never be nil as the object with the given key must exist
  -- (if it didn't exist, this get function would not be called)
  return info.alias
end

local function do_set(db, mapping, _, value, key)
  local info = db:getAlias(mapping.tp_id, key)
  if value ~= info.alias then
    if value:match("^%a[%a%d_-]*$") and (#value<=64) then
      if not db:setAliasForId(info.id, value) then
        return nil, "alias value is not unique"
      end
    else
      return nil, "value is invalid"
    end
  end
end

local function do_accessors(mapping, get, set)
  local paramName = mapping.objectType.aliasParameter
  if paramName and mapping.objectType.parameters[paramName] then
    return get, set
  end
end

function M.new(store)
  local get = function(...)
    return do_get(store.persistency._db, ...)
  end
  local set = function(...)
    return do_set(store.persistency._db, ...)
  end

  return {
    accessors = function(mapping)
      return do_accessors(mapping, get, set)
    end
  }
end

return M
