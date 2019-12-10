#!/usr/bin/env lua

local proxy = require("datamodel")
local ubus = require("ubus")

local ubus_conn
local args = {...}

ubus_conn = ubus.connect()

if not ubus_conn then
  log:error("Failed to connect to ubus")
end

if args[1] == "On" then
   proxy.set("uci.wireless.wifi-device.@radio_2G.state","1")
   proxy.set("uci.wireless.wifi-device.@radio_5G.state","1")
   ubus_conn:send("event",{ state="wifi_leds_on" })
elseif args[1] == "Off" then
   proxy.set("uci.wireless.wifi-device.@radio_2G.state","0")
   proxy.set("uci.wireless.wifi-device.@radio_5G.state","0")
   ubus_conn:send("event",{ state="wifi_leds_off" })
else
   local state2G = proxy.get("uci.wireless.wifi-device.@radio_2G.state")[1].value
   local state5G = proxy.get("uci.wireless.wifi-device.@radio_5G.state")[1].value
   if state2G == "1" or state5G == "1" then
      proxy.set("uci.wireless.wifi-device.@radio_2G.state","0")
      proxy.set("uci.wireless.wifi-device.@radio_5G.state","0")
      ubus_conn:send("event",{ state="wifi_leds_off" })
   else
      proxy.set("uci.wireless.wifi-device.@radio_2G.state","1")
      proxy.set("uci.wireless.wifi-device.@radio_5G.state","1")
      ubus_conn:send("event",{ state="wifi_leds_on" })
   end
end

proxy.apply()
