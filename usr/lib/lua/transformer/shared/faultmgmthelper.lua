local require = require
local setmetatable = setmetatable
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local format = string.format
local sort = table.sort
local match = string.match
local ubus = require('transformer.mapper.ubus').connect()
local duplicator = require('transformer.mapper.multiroot').duplicate

local M = {}

local ElementList = {}
ElementList.__index = ElementList

-- sorted by number
local function nsort(a,b)
  local na = tonumber(match(a, "|(.*)$"))
  local nb = tonumber(match(b, "|(.*)$"))
  return na < nb
end

--- retrieve keys for all alarm event table for transformer
-- @param parentkey [string] the key of the parent instance.
-- @returns a list (table) of keys to pass to transformer
function ElementList:getKeys(parentkey)
  self.keys = {}
  self.entries = ubus:call("faultmgmt.event", "get",{["table_name"] = self.tablename})

  for key,_ in pairs(self.entries or {}) do
    self.keys[#self.keys+1] = key
  end

  if self.tablename ~= "supported" then
    sort(self.keys, nsort)
  else
    sort(self.keys)
  end

  return self.keys
end

--- register the mapping to IGD and Device
-- @param mapping [table] the mapping
-- @param register [function] the register function
function M.register(mapping, register)
  local duplicates = duplicator(mapping, "#ROOT", {"InternetGatewayDevice", "Device"})
  for _,dupli in ipairs(duplicates) do
    register(dupli)
  end
end

--- create a new table list for the given mapping
-- @param mapping [table] a mapping
-- @param tablename [string] the alarm event table name,
--        it could be "supported", "current", "expedited", "queued" and "history"
function M.SetElementList(mapping, tablename)
  local alarm = {
    tablename = tablename,
  }

  mapping._alarm = setmetatable(alarm, ElementList)
  return alarm
end

return M
