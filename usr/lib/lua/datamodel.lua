local require = require

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
