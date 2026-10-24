#!/usr/bin/lua

local ubus, uloop = require('ubus'), require('uloop')
local helper = require("mobiled.scripthelpers")

local log = require('tch.logger')
local posix = require("tch.posix")
log.init("mobiled-netifd", 6, posix.LOG_PID)

local netifd_helper = {
	helper_script = "/lib/netifd/mobiled.script",
	ubus_event_data = {},
	action_queue = {}
}

function netifd_helper:get_device_idx(dev_desc)
	if not dev_desc then return 1 end
	local ret = self.ubus:call("mobiled.device", "get", { dev_desc = dev_desc })
	if not ret then return 1 end
	return ret.dev_idx or 1
end

function netifd_helper:init(config)
	uloop.init()
	self.ubus = ubus.connect(nil, 10)
	if not self.ubus then
		return nil, "Failed to connect to UBUS"
	end

	self.config = config
	for k, v in pairs(self.config) do
		self.ubus_event_data[k] = v
	end

	self.ubus_event_data.event = "session_activate"
	self.ubus_event_data.dev_idx = self:get_device_idx(self.config.dev_desc)
	self.ubus:send("mobiled", self.ubus_event_data)

	local ubus_events = {
		['mobiled'] = function(...)
			self:handle_event('mobiled', ...)
		end,
		['mobiled.network'] = function(...)
			self:handle_event('mobiled.network', ...)
		end
	}
	self.ubus:listen(ubus_events)

	return true
end

function netifd_helper:stop()
	log:info('Terminating data session "%s"', self.config.interface)
	local dev_idx = self:get_device_idx(self.config.dev_desc)
	self.ubus_event_data.event = "session_deactivate"
	self.ubus_event_data.dev_idx = dev_idx
	self.ubus:send("mobiled", self.ubus_event_data)

	if not self.config.optional then
		local count = 30
		while count > 0 do
			local ret = self.ubus:call("mobiled.network", "sessions", { session_id = self.config.session_id, dev_idx = dev_idx })
			if not ret or not ret.session_state or ret.session_state == "disconnected" or ret.session_state == "disconnecting" then
				break
			end
			count = count -1
			log:debug('Waiting for data session "%s" to terminate', self.config.interface)
			helper.sleep(1)
		end
		if count > 0 then
			log:info('Terminated data session "%s"', self.config.interface)
		else
			log:error('Failed to terminated data session "%s"', self.config.interface)
		end
	end
end

function netifd_helper:handle_event(event_type, event_data)
	local dev_idx = self:get_device_idx(self.config.dev_desc)

	if event_type == "mobiled" then
		if not event_data or not event_data.event then
			return
		end
		if event_data.event == "device_initialized" and event_data.dev_idx == dev_idx then
			self.ubus_event_data.dev_idx = dev_idx
			self.ubus:send("mobiled", self.ubus_event_data)
		elseif event_data.event == "session_state_changed" and
				tonumber(event_data.session_id) == self.config.session_id and
				event_data.dev_idx == dev_idx and event_data.session_state then
			local pdp_type = event_data.pdp_type or "ipv4v6"
			self:queue_action({
				action = event_data.session_state,
				params = {self.config.session_id, dev_idx, self.config.interface, pdp_type, event_data.session_state}
			})
		elseif event_data.event == "device_removed" and event_data.dev_idx == dev_idx then
			self:queue_action({
				action = "teardown",
				params = {self.config.session_id, dev_idx, self.config.interface, "ipv4v6", "teardown"}
			})
		end
	elseif event_type == "mobiled.network" then
		if (event_data.action == "ifup" or event_data.action == "ifupdate") and event_data.interface and string.match(event_data.interface, self.config.interface) then
			self:queue_action({
				action = "augment",
				params = {self.config.session_id, dev_idx, self.config.interface, "ipv4v6", "augment"}
			})
		end
	end
end

function netifd_helper:queue_action(action)
	log:debug("Queuing %s action on interface %s", action.action, self.config.interface)
	table.insert(self.action_queue, action)
	self:run_next_action()
end

function netifd_helper:action_completed(action, return_code)
	self.running_action = nil
	log:debug("Action %s completed with return code %d on interface %s", action, return_code, self.config.interface)
	self:run_next_action()
end

function netifd_helper:run_next_action()
	if not self.running_action then
		local action = table.remove(self.action_queue, 1)
		if action then
			log:debug("Running %s action on interface %s", action.action, self.config.interface)
			uloop.process(self.helper_script, action.params, {}, function(...) self:action_completed(action.action, ...) end)
			self.running_action = action
		end
	end
end

local config = {
	optional = false
}

for option, argument in helper.getopt(arg, 's:p:d:i:b:o') do
	if option == "s" then
		config.session_id = tonumber(argument)
	elseif option == "p" then
		config.profile_id = argument
	elseif option == "d" then
		if argument ~= "" then config.dev_desc = argument end
	elseif option == "i" then
		if argument ~= "" then config.interface = argument end
	elseif option == "b" then
		if argument ~= "" then config.bridge = argument end
	elseif option == "o" then
		config.optional = true
	end
end

if not config.session_id or not config.profile_id or not config.interface then
	log:error("Invalid session ID, profile or interface")
	return
end

netifd_helper:init(config)
uloop.run()
netifd_helper:stop()
