#!/usr/bin/env lua



local ubus, uloop = require('ubus'), require('uloop')

uloop.init()



local conn = ubus.connect()
if not conn then
	error("Failed to connect to ubusd")
end

local timer 
local function polling()
		local data = conn:call("mmpbx.device", "get", {})
		if data ~= nil then
		local packet = {}
		for device, status in pairs (data) do
		if (device == "fxs_dev_0") or (device == "fxs_dev_1") then
		packet[device] = status["deviceUsable"] and status["profileUsable"]
		end
		end
		conn:send("mmpbx.profilestate", packet)
		end
timer:set(500)
end

timer = uloop.timer(polling)
timer:set(10000)

while true do
 uloop.run()
end
