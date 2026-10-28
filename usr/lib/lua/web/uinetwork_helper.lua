local M = {}

local type, require, ipairs = type, require, ipairs
local format = string.format
local ch = require("web.content_helper")
local proxy = require("datamodel")
local ww = require("web.web")
local bit = require("bit")

---
-- @param #string basepath
-- @return #table
function M.getHostsList()
    local basepath = "sys.hosts.host."
    local data = proxy.get(basepath)
    local result = {}

    if type(data) == "table" then
        result = ch.convertResultToObject(basepath, data)
    end
    return result
end

---
local ipv6_pattern = "%x*:%x*:%x*:%x*:%x*:%x*:%x*:%x*"
local ipv4_pattern = "%d+%.%d+%.%d+%.%d+"
local mac_pattern = "%x*:%x*:%x*:%x*:%x*:%x*"
-- @param skipIPv6LinkLocal [optional] to get only IPv6 address (not link local address)
-- @return 2 tables: 1 IPv4 hosts, 2 IPv6 hosts
function M.getAutocompleteHostsList(skipIPv6LinkLocal)
    local hosts = M.getHostsList()
    local ipv4hosts={}
    local ipv6hosts={}

    for i,v in ipairs(hosts) do
        local name = ww.html_escape(v.FriendlyName)
        local iplist = ww.html_escape(v.IPAddress)
        local macaddr = ww.html_escape(v.MACAddress)
        local friendlyName
        local ipv6list = ww.html_escape(v.IPv6)

        --Get the IPv4 hosts
        for ipv4 in iplist:gmatch(ipv4_pattern) do
            --The sys.hosts.host will never return empty value for FriendlyName.
            --For example the default value will be Unknown-b4:ef:fa:b7:f5:98 if host name is empty
            if name:match(mac_pattern) then
                friendlyName = ipv4
            else
                friendlyName = name .. " (" .. ipv4 .. ")"
            end
            friendlyName = friendlyName .. " [" .. macaddr .. "]"
            ipv4hosts[friendlyName] = ipv4
        end

        --Get the IPv6 hosts
        if ipv6list and ipv6list ~= "" then
          if name:match(mac_pattern) then
            friendlyName = ipv6list
          else
            friendlyName = name .. "(" .. ipv6list .. ")"
          end
          friendlyName = friendlyName .. " [" .. macaddr .. "]"
          if skipIPv6LinkLocal then
            if bit.band(ipv6list:byte(1), 0xE0) == 0x20 then
              ipv6hosts[friendlyName] = ipv6list
            end
          else
            ipv6hosts[friendlyName] = ipv6list
          end
        end
    end
    return ipv4hosts, ipv6hosts
end

---
-- @return #table
function M.getAutocompleteHostsListIPv4()
    return (M.getAutocompleteHostsList())
end

return M
