local M = {}

local type, require, ipairs = type, require, ipairs
local format = string.format
local ch = require("web.content_helper")
local proxy = require("datamodel")
local ww = require("web.web")

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
-- @return 2 tables: 1 IPv4 hosts, 2 IPv6 hosts
function M.getAutocompleteHostsList()
    local hosts = M.getHostsList()
    local ipv4hosts={}
    local ipv6hosts={}

    for i,v in ipairs(hosts) do
        if v.FirewallZone == "LAN" then
	    local name = ww.html_escape(v.HostName)
	    local iplist = ww.html_escape(v.IPAddress)
            local macaddr = ww.html_escape(v.MACAddress)
	    local friendlyName

            --Get the IPv4 hosts
	    local ip = iplist:match("%d+%.%d+%.%d+%.%d+") -- match first IPv4 in list (will have to do for now)
	    if ip then
		if name == "" then
			friendlyName = ip
		else
			friendlyName = name .. " (" .. ip .. ")"
		end
		friendlyName = friendlyName .. " [" .. macaddr .. "]"
		ipv4hosts[friendlyName] = ip
	    end

            --Get the IPv6 hosts
	    for ipv6 in iplist:gmatch(ipv6_pattern) do
                if ipv6 then
                    if name == "" then
                        friendlyName = ipv6
                    else
			friendlyName = name .. "(" .. ipv6 .. ")"
                    end
                    friendlyName = friendlyName .. " [" .. macaddr .. "]"
                    ipv6hosts[friendlyName] = ipv6
                end
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
