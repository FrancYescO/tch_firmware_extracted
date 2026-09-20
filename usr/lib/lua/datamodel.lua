local require = require

local proxy = require("datamodel-bck")

local fd = assert(io.open("/proc/sys/kernel/random/uuid", "r"))
local uuid = fd:read('*l')
uuid = string.gsub(uuid,"-","")
fd:close()

local M = {}

M.__index = function (table, key)
  return function(...)
    return proxy[key](uuid, ...)
  end
end

return setmetatable({},M)