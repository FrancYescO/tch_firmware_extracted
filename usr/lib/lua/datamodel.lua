--[[
Copyright (c) 2016 Technicolor Delivery Technologies, SAS

The source code form of this Transformer component is subject
to the terms of the Clear BSD license.

You can redistribute it and/or modify it under the terms of the
Clear BSD License (http://directory.fsf.org/wiki/License:ClearBSD)

See LICENSE file for more details.
]]

local proxy = require("datamodel-bck")

local fd = assert(io.open("/proc/sys/kernel/random/uuid", "r"))
local uuid = fd:read('*l')
uuid = string.gsub(uuid,"-","")
fd:close()

local M = {}

M.__index = function (table, key)
  local f = function(...)
    return proxy[key](uuid, ...)
  end
  table[key] = f
  return f
end

return setmetatable({},M)
