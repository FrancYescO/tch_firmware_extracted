local uciconv = require 'uciconv'
local uciOld = uciconv.uci('old')
local uciNew = uciconv.uci('new')
local intfList = {}

local oldData = uciconv.load(uciOld, "firewall", "@helper")
oldData:each(function(section)
  local intf = section.intf or "lan"
  intfList[intf] = intfList[intf] or {}
  local enable = section.enable or "1"
  if enable == "0" then
    intfList[intf][section.helper] = true
  end
end)

local newData = uciconv.load(uciNew, "firewall", "@zone")
newData:each(function(section)
  local newList = {}
  for _, helper in pairs(section.helper or {}) do
    if not (intfList[section.name] and intfList[section.name][helper]) then
      newList[#newList + 1] = helper
    end
  end
  uciNew:set("firewall", section.name, "helper", newList)
end)

uciNew:save("firewall")
