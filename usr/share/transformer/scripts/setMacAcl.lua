#!/usr/bin/env lua

local uci = require("uci")
local cursor = uci.cursor()
local ubus = require("ubus")
local conn = ubus.connect()
if not conn then
  error("Failed to connect to ubusd")
end

local ubusModeMap = {
  disabled = 3,
  unlock = 2,
  lock = 1,
}

local function setMacAclCall()
  local rfile = io.open("/tmp/.setMacAcl", "r")
  if not rfile then
    return
  end
  local acl_ap = rfile:read()
  rfile:close()
  if acl_ap == nil then
    return
  end
  local aclmode = cursor:get("wireless."..acl_ap..".acl_mode")
  if aclmode == "register" then
    return
  end
  local mac
  local macList = {}
  local string, table = string, table
  local aclType = ubusModeMap[aclmode]
  local iface = cursor:get("wireless."..acl_ap..".iface")
  local radio = cursor:get("wireless."..iface..".device")
  if aclType == 1 then
    mac = cursor:get("wireless."..acl_ap..".acl_accept_list")
  elseif aclType == 2 then
    mac = cursor:get("wireless."..acl_ap..".acl_deny_list")
  end
  if type(mac) ~= "table" then
    aclType = 3
  else
    for _,macaddr in pairs(mac) do
      local mac_without_colon = string.gsub(macaddr,"%W","")
      macList[#macList + 1] = mac_without_colon
    end
  end
  if aclType == 3 then
    conn:call("mapVendorExtensions.controller", "setMacAcl", {Radio = radio, AclType = 3})
  else
    conn:call("mapVendorExtensions.controller", "setMacAcl", {StaList = macList, Radio = radio, AclType = aclType})
  end
end

setMacAclCall()
