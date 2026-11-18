#!/usr/bin/env lua

--To Restrict already connected devices internet connectivity
local function disableInternetAccess(ipAddress)
  if next(ipAddress) then
    for _, ipData in pairs(ipAddress) do
      if ipData.state == "connected" and ipData.address then
        local ip = ipData.address
        os.execute(string.format("conntrack -D -s %s", ip))
        os.execute(string.format("conntrack -D -r %s", ip))
        break
      end
    end
  end
end

--To Restrict LAN Device Internet Connectivity
local function restrictLANDevice(data)
  if data and data.interface == "lan" then
    if data.ipv4 then
      disableInternetAccess(data.ipv4)
    end
    if data.ipv6 then
      disableInternetAccess(data.ipv6)
    end
  end
end

local conn = require("transformer.mapper.ubus").connect()
local ubusData = conn:call("hostmanager.device", "get", {})
if ubusData then
  for _, data in pairs(ubusData) do
    restrictLANDevice(data)
  end
end
