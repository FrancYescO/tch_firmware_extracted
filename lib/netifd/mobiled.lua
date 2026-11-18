#!/usr/bin/lua

local os, require, tonumber, arg = os, require, tonumber, arg
local ubus, uloop = require('ubus'), require('uloop')
local helper = require("mobiled.scripthelpers")

local logger = require("transformer.logger")
local log = logger.new("mobiled", 6)

local session_id, profile_id, dev_desc, interface

for option, argument in helper.getopt(arg, 's:p:d:i:r') do
	if(option == "s") then
		session_id = tonumber(argument)
	elseif(option == "p") then
		profile_id = argument
	elseif(option == "d") then
		if argument ~= "" then dev_desc = argument end
	elseif(option == "i") then
		if argument ~= "" then interface = argument end
	end
end

if not session_id or not profile_id or not interface then
	log:error("Please pass a valid session ID, profile and interface")
	return
end

local conn

local function get_device_idx(desc)
	if not desc then return 1 end
	local ret = conn:call("mobiled.device", "get", { dev_desc = desc })
	if not ret then return 1 end
	return ret.dev_idx or 1
end

uloop.init()
conn = ubus.connect()
if not conn then
	log:error("Failed to connect to UBUS")
	return 1
end

local event_data = { event = "session_activate", session_id = session_id, profile_id = profile_id, interface = interface }
event_data.dev_idx = get_device_idx(dev_desc)
conn:send("mobiled", event_data)

local events = {}
events['mobiled'] = function(msg)
	if not msg or not msg.event then
		return
	end
	if (msg.event == "device_initialized" or msg.event == "network_registered") and (msg.dev_desc == dev_desc or not dev_desc) then
		event_data.dev_idx = msg.dev_idx
		conn:send("mobiled", event_data)
	elseif msg.event == "session_state_changed" and tonumber(msg.session_id) == session_id and (msg.dev_desc == dev_desc or not dev_desc) and msg.session_state then
		local cmd = string.format("/lib/netifd/mobiled.script %d %d %s %s", session_id, msg.dev_idx, interface, msg.session_state)
		os.execute(cmd)
	end
end
-- Listen for ifup events of my own interface. In case of ME906 we want to use this event to augment the DHCP retrieved parameters with DNS addresses read out using AT commands
events['mobiled.network'] = function(msg)
	if (msg.action == "ifup" or msg.action == "ifupdate") and msg.interface and string.match(msg.interface, interface) then
		local cmd = string.format("/lib/netifd/mobiled.script %d %d %s %s", session_id, event_data.dev_idx, interface, "augment")
		os.execute(cmd)
	end
end

conn:listen(events)
uloop.run()

log:info("Terminating data session: " .. interface)

event_data.event = "session_deactivate"
event_data.dev_idx = get_device_idx(dev_desc)
conn:send("mobiled", event_data)

local count = 30
while count > 0 do
	local ret = conn:call("mobiled.network", "sessions", { session_id = session_id, dev_idx = event_data.dev_idx })
	if not ret or not ret.session_state or ret.session_state == "disconnected" or ret.session_state == "disconnecting" then
			break
	end
	count = count -1
	log:info(string.format('Waiting for data session "%s" to terminate', interface))
	helper.sleep(1)
end
log:info(string.format('Terminated data session "%s"', interface))
