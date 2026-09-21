#!/usr/bin/env lua
local uci = require("uci")
local cursor = uci.cursor(nil, "/var/state")
local proxy = require("datamodel")

local is_5g_device_connected = function ()
    local host_list = proxy.get("sys.hosts.host.")
    if host_list then
      for _, host in pairs(host_list) do
        if type(host) == "table" and  host["param"] == "L2Interface" then
          if (host["value"] == "wl1") or (host["value"] == "eth5") then
            return "Completed (5GHz present)"
          end
        end
      end
    end
    if proxy.set("Device.Services.X_BELGACOM_EnhancedWiFi.Enable", "1") then
      proxy.apply()
      return "Completed"
    else
      return "Error"
    end
end

local isFiveGDeviceConnected = is_5g_device_connected()
cursor:revert("enhancedwifi","global","single_ssid_state")
cursor:set("enhancedwifi","global","single_ssid_state", isFiveGDeviceConnected)
cursor:save("enhancedwifi")
cursor:close()
