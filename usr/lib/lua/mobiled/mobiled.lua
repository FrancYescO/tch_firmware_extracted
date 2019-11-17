---------------------------------
--! @file
--! @brief The mobiled module containing glue logic for the entire Mobiled
---------------------------------

local mobiled_statemachine = require('mobiled.statemachine')
local mobiled_plugin = require('mobiled.plugin')
local mobiled_device = require('mobiled.device')
local detector = require('mobiled.detector')
local helper = require("mobiled.scripthelpers")
local mobiled_ubus = require('mobiled.ubus')
local version = require('mobiled.version')
local errors = require('mobiled.error')
local sms = require('mobiled.sms')
local json = require('dkjson')

local M = {
	stats = {
		interfaces = {}
	}
}

local runtime
local plugins = {}
local stateMachines = {}

local device_index = 1

local init_processes = {}
local initialized_devices = {}
local scan_timer

local SCAN_DELAY = 2000
local SCAN_INTERVAL = 30000

function M.cleanup()
	runtime.log:info("Cleaning up...")
	for i=#stateMachines,1,-1 do
		local sm = stateMachines[i]
		if sm.device then
			M.stop_device(sm.device, false)
		end
		table.remove(stateMachines, i)
	end

	for i=#plugins,1,-1 do
		local p = plugins[i]
		p:destroy()
		table.remove(plugins, i)
	end

	runtime.ubus:close()
	runtime.uloop.cancel()
end

function M.reloadconfig(force)
	runtime.log:info("Reloading config")
	runtime.config.reloadconfig(stateMachines, plugins, force)
end

local function notify_device_connected(dev_desc)
	for _, sm in ipairs(stateMachines) do
		if not sm.device then
			sm:handle_event({
				event = "device_connected",
				dev_desc = dev_desc
			})
			break
		end
	end
end

local function run_init_script(detected_device)
	local config = M.get_config()
	for _, init_script in pairs(config.init_scripts) do
		if init_script.dev_descs[detected_device.dev_desc] then
			-- Fill in the placeholders in the arguments.
			local arguments = {}
			for _, argument in ipairs(init_script.arguments) do
				local expanded_argument = argument:gsub(
					"(<%s*(%w+)%s*>)",
					function(literal, placeholder)
						if placeholder == "lt" then
							return "<"
						elseif placeholder == "gt" then
							return ">"
						else
							local replacement = detected_device[placeholder]
							if type(replacement) == "string" then
								return replacement
							else
								return literal
							end
						end
					end
				)
				table.insert(
					arguments,
					expanded_argument
				)
			end

			-- Start the init script.
			runtime.log:info("running init script %s for device %s", init_script.command, detected_device.dev_desc)
			init_processes[detected_device.dev_desc] = runtime.uloop.process(
				init_script.command,
				arguments,
				{},
				function(exit_status)
					if exit_status == 0 then
						runtime.log:info("init script %s exited successfully for device %s", init_script.command, detected_device.dev_desc)
						initialized_devices[detected_device.dev_desc] = detected_device
						notify_device_connected(detected_device.dev_desc)
					else
						runtime.log:info("init script %s exited unsuccessfully for device %s", init_script.command, detected_device.dev_desc)
					end
					init_processes[detected_device.dev_desc] = nil
				end
			)

			-- Only execute the first init script that matches.
			return
		end
	end

	runtime.log:info("not running init script for device %s", detected_device.dev_desc)
	initialized_devices[detected_device.dev_desc] = detected_device
	notify_device_connected(detected_device.dev_desc)
end

local function scan_for_new_devices()
	while true do
		local detected_device = detector.scan(runtime)
		if not detected_device then
			scan_timer:set(SCAN_INTERVAL)
			break
		end
		run_init_script(detected_device)
	end
end

function M.init(rt)
	runtime = rt

	local c = M.get_config()
	local ret, errMsg = sms.init(rt, { db_path = c.sms_database_path, max_messages = c.sms_max_messages })
	if not ret then
		return nil, errMsg
	end

	M.platform = require('mobiled.platform')
	M.platform.init(runtime)
	ret, errMsg = mobiled_ubus.init(runtime)
	if not ret then
		return nil, errMsg
	end

	local status, m = pcall(require, "mobiled.plugins.apn-autoconf")
	M.apn_autoconf = status and m or nil

	M.started_uptime = helper.uptime()

	scan_timer = runtime.uloop.timer(
		scan_for_new_devices,
		SCAN_DELAY
	)

	return true
end

local function ubus_send_reply(req, resp)
	runtime.ubus:reply(req, resp)
end

local function load_plugin(name, params)
	local plugin = M.get_plugin(name)
	if not plugin then
		local errMsg
		plugin, errMsg = mobiled_plugin.create(runtime, name, params)
		if not plugin then
			return nil, errMsg
		end
		if plugin.plugin.get_ubus_methods then
			local methods = plugin.plugin.get_ubus_methods(ubus_send_reply)
			if methods then
				runtime.ubus:add(methods)
			end
		end
		table.insert(plugins, plugin)
	end
	return plugin
end

function M.device_exists(dev_desc)
	for _, sm in ipairs(stateMachines) do
		if (sm.device and sm.device.desc == dev_desc) then
			return true
		end
	end
	return not not init_processes[dev_desc] or not not initialized_devices[dev_desc]
end

function M.add_device(dev_idx)
	local dev_desc, params = next(initialized_devices)
	if not params then
		return nil
	end

	local sm = stateMachines[dev_idx]
	if not sm or sm.device then
		return nil, "No statemachine available to add device"
	end

	initialized_devices[dev_desc] = nil

	local c = M.get_config()

	local plugin, errMsg = load_plugin(params.plugin_name, { tracelevel = c.tracelevel })
	if not plugin then return nil, errMsg end

	local device
	params.dev_idx = sm.dev_idx
	device, errMsg = mobiled_device.create(runtime, params, plugin)
	if not device then return nil, errMsg end

	sm.device = device
	sm.device.sm = sm

	--[[
		Populate the data session list extracted from the UCI network config
		at creation of the device. This session info is needed to correctly configure
		the attach context.
		Additional data sessions can be created or existing sessions can be updated by Netifd sending the session_activate event.
	]]
	for _, session_config in pairs(runtime.config.get_session_config(device)) do
		_, errMsg = M.add_data_session(device, session_config)
		if errMsg then runtime.log:warning(errMsg) end
	end

	runtime.events.send_event("mobiled", { event = "device_added", dev_idx = sm.dev_idx, dev_desc = sm.device.desc })

	M.start_new_statemachine()
	return device
end

function M.stop_device(device, force)
	if not force then
		M.stop_all_data_sessions(device)
	end
	M.propagate_session_state(device, "disconnected", "ipv4v6", device:get_data_sessions())
	device:destroy(force)
end

function M.remove_device(device)
	for i=#stateMachines,1,-1 do
		local sm = stateMachines[i]
		if(sm.device and sm.device.desc == device.desc) then
			local desc = device.desc
			M.stop_device(sm.device, true)
			runtime.log:info("Removed statemachine " .. sm.dev_idx)
			table.remove(stateMachines, i)
			runtime.events.send_event("mobiled", { event = "device_removed", dev_idx = sm.dev_idx, dev_desc = desc })
			break
		end
	end
	device_index = 1
	for _, sm in pairs(stateMachines) do
		sm.dev_idx = device_index
		device_index = device_index + 1
	end
	M.start_new_statemachine()
end

function M.get_device(dev_idx)
	for _, sm in pairs(stateMachines) do
		if sm.device and (sm.dev_idx == dev_idx or not dev_idx) then
			return sm.device
		end
	end
	return nil, "No device found with index " .. tostring(dev_idx)
end

function M.get_device_by_imei(imei)
	for _, sm in pairs(stateMachines) do
		if sm.device and sm.device.info.imei == imei then
			return sm.device
		end
	end
	return nil, "No device found with IMEI " .. tostring(imei)
end

function M.get_device_by_desc(desc)
	for _, sm in pairs(stateMachines) do
		if sm.device and (sm.device.desc == desc or not desc) then
			return sm.device
		end
	end
	return nil, "No device found with description " .. tostring(desc)
end

function M.get_devices()
	local devices = {}
	for _, sm in pairs(stateMachines) do
		if sm.device then
			table.insert(devices, sm.device)
		end
	end
	return devices
end

function M.get_device_count()
	local devices = 0
	for _, sm in pairs(stateMachines) do
		if sm.device then
			devices = devices + 1
		end
	end
	return devices
end

function M.get_statemachines()
	return stateMachines
end

function M.get_plugins()
	return plugins
end

function M.get_plugin(name)
	for _, p in pairs(plugins) do
		if p.name == name then
			return p
		end
	end
	return nil, "No plugin found with name " .. tostring(name)
end

function M.get_attach_context(device)
	local sessions = device:get_data_sessions()
	if sessions[0] then
		return sessions[0], M.get_profile(device, sessions[0].profile_id)
	end
end

function M.configure_attach_context(device, session, profile)
	local log = runtime.log
	if session and session.changed and profile then
		local info = device:get_network_info()
		if info and info.nas_state == "registered" then
			log:info("Detaching from network")
			if not device:network_detach() then
				log:warning("Failed to detach")
			end
		end
		log:info("Configuring attach profile")
		if not device:set_attach_params(profile) then
			return nil, "Failed to configure attach context"
		end
		session.changed = false
	end
	return true
end

function M.get_profile(device, profile_id)
	if not profile_id then
		return nil, "No profile specified"
	end
	-- Check if the profile we want to use is a reused device profile
	local device_profile_id = tonumber(string.match(profile_id, "^device:(.*)$"))
	if device_profile_id then
		local profile = { device_profile = true, id = device_profile_id }
		local info = device:get_profile_info()
		if type(info) == "table" and type(info.profiles) == "table" then
			for _, p in pairs(info.profiles) do
				if tonumber(p.id) == profile.id then
					for k, v in pairs(p) do
						profile[k] = v
					end
					return profile
				end
			end
		end
		return nil, "Invalid device profile specified"
	end
	return runtime.config.get_profile(profile_id)
end

function M.add_data_session(device, session_config)
	-- Verify if the profile exists
	local profile, errMsg = M.get_profile(device, session_config.profile_id)
	if profile then
		local session
		session, errMsg = device:add_data_session(session_config)
		if session then
			session.allowed = M.apn_is_allowed(device, profile.apn)
			return session
		end
	end
	return nil, errMsg
end

function M.activate_data_session(device, session_config)
	local log = runtime.log
	local session, errMsg = M.add_data_session(device, session_config)
	if session then
		session.activated = true
		log:info("Activated data session " .. tostring(session.session_id) .. " using profile " .. tostring(session.profile_id))
		runtime.events.send_event("mobiled", { event = "session_setup", session_id = session.session_id, dev_idx = device.sm.dev_idx })
	elseif errMsg then
		log:warning(errMsg)
	end
end

function M.deactivate_data_session(device, session_id)
	local log, events = runtime.log, runtime.events
	local ret, errMsg = device:deactivate_data_session(session_id)
	if ret then
		events.send_event("mobiled", { event = "session_teardown", session_id = session_id, dev_idx = device.sm.dev_idx })
	elseif errMsg then
		log:warning(errMsg)
	end
end

function M.start_data_session(device, session_id, profile)
	local session = device:get_data_session(session_id)
	profile.bridge = session.bridge
	M.propagate_session_state(device, "setup", "ipv4v6", { session })
	local internal = false
	if session then
		internal = session.internal or false
	end
	return device:start_data_session(session_id, profile, internal)
end

function M.stop_data_session(device, session_id)
	local session = device:get_data_session(session_id)
	-- We need this teardown event here in order to kill the PPP interface otherwise the state will never change to disconnected
	M.propagate_session_state(device, "teardown", "ipv4v6", { session })
	return device:stop_data_session(session_id)
end

function M.stop_all_data_sessions(device)
	for _, session in pairs(device:get_data_sessions() or {}) do
		M.stop_data_session(device, session.session_id)
	end
end

function M.get_data_session(device, session_id)
	local session, errMsg = device:get_data_session(session_id)
	return session or nil, errMsg
end

function M.get_config()
	return runtime.config.get_config()
end

function M.get_device_config(device)
	local cfg, errMsg = runtime.config.get_device_config(device)
	if cfg then
		cfg.sim_hotswap = M.platform.sim_hotswap_supported(device)
	end
	return cfg, errMsg
end

function M.validate_imsi(imsi)
	local config = M.get_config()
	if type(config.allowed_imsi_ranges) == "table" then
		for _, pattern in pairs(config.allowed_imsi_ranges) do
			if string.match(imsi, pattern) then
				return true
			end
		end
		return false
	end
	return true
end

function M.validate_roaming(imsi, mcc, mnc, roaming)
	if roaming == "national" then
		return imsi:sub(1, 3) == mcc
	elseif roaming == "none" then
		return helper.startswith(imsi, mcc .. mnc)
	end
	return true
end

function M.validate_plmn(mcc, mnc)
	local config = M.get_config()
	if type(config.operators) == "table" then
		for _, operator in pairs(config.operators) do
			if operator.mcc .. operator.mnc == mcc .. mnc then
				return true
			end
		end
		return false
	end
	return true
end

function M.clear_pin()
	runtime.config.remove_all_pin_from_config()
end

function M.get_pin_from_config(pinType, iccid)
	return runtime.config.get_pin_from_config(pinType, iccid)
end

function M.remove_pin_from_config(pinType, iccid)
	runtime.config.remove_pin_from_config(pinType, iccid)
end

function M.store_pin_to_config(pinType, pin, iccid)
	local config = M.get_config()
	if config and config.store_pin then
		return runtime.config.store_pin_to_config(pinType, pin, iccid)
	end
end

function M.unlock_pin_from_config(device, pinType)
	if not device.iccid then
		return nil, "Invalid ICCID"
	end
	local pin = M.get_pin_from_config(pinType, device.iccid)
	if pin then
		local ret, errMsg = device:unlock_pin(pinType, pin)
		if not ret then
			M.remove_pin_from_config(pinType, device.iccid)
			return ret, errMsg
		end
		return true
	end
	return nil, "No PIN stored in config"
end

function M.propagate_session_state(device, session_state, pdp_type, sessions)
	if type(sessions) ~= "table" then return end
	for _, session in pairs(sessions) do
		runtime.events.send_event("mobiled", { dev_idx = device.sm.dev_idx, dev_desc = device.desc, event = "session_state_changed", session_state = session_state, session_id = session.session_id, pdp_type = pdp_type })
	end
end

function M.start_new_statemachine()
	local c = M.get_config()
	local smAvailable = false
	for _, sm in pairs(stateMachines) do
		if not sm.device then 
			smAvailable = true
			break
		end
	end
	if not smAvailable and #stateMachines < c.max_devices then
		runtime.log:info("Adding statemachine " .. device_index)
		-- Create a statemachine to look for new devices
		local config = runtime.config.get_raw_config()
		local sm = mobiled_statemachine.create(config.states, config.globals.initmode, runtime, device_index, M.handle_event)
		table.insert(stateMachines, sm)
		sm:start()
		device_index = device_index + 1
	end
end

function M.get_state(dev_idx)
	if not dev_idx then dev_idx = 1 end
	for _, sm in ipairs(stateMachines) do
		if sm.dev_idx == dev_idx then
			return sm:get_state()
		end
	end
	return nil, "No such statemachine (" .. tostring(dev_idx) .. ")"
end

function M.get_display_state(dev_idx)
	local state = M.get_state(dev_idx)
	local state_map = {
		["WaitingForDevice"]	= "no_device",
		["DeviceInit"]			= "configuring_device",
		["DeviceConfigure"]		= "configuring_device",
		["SimInit"]				= "configuring_device",
		["DeviceRemove"]		= "configuring_device",
		["UnlockSim"]			= "initializing_sim",
		["RegisterNetwork"]		= "connecting",
		["DataSessionSetup"]	= "connecting",
		["NetworkScan"]			= "scanning_network",
		["FirmwareUpgrade"]		= "upgrading_firmware",
		["SelectAntenna"]		= "configuring_device",
		["PlatformConfigure"]	= "configuring_device",
		["Disabled"]			= "disabled",
		["Error"]				= "error"
	}
	local display_state = state_map[state]
	if state == "Idle" then
		local device = M.get_device(dev_idx)
		if device then
			local sessions = device:get_data_sessions()
			if sessions[0] and sessions[0].activated and sessions[0].allowed then
				display_state = "connected"
			else
				display_state = "disconnected"
			end
		end
	end
	return display_state
end

function M.get_version()
	return version.version()
end

function M.add_error(device, severity, error_type, error_message)
	errors.add_error(device, severity, error_type, error_message)
end

function M.get_sms_messages()
	M.sync_sms_messages()
	return sms.get_messages() or {}
end

function M.set_sms_status(id, status)
	return sms.set_message_status(id, status)
end

function M.delete_sms(id)
	return sms.delete_message(id)
end

function M.get_sms_info()
	return sms.get_info()
end

-- Retrieves all messages from a device, stores them in the SMS database and deletes them on the device
function M.sync_sms_messages()
	for _, sm in ipairs(stateMachines) do
		if sm.device then
			sms.sync(sm.device)
		end
	end
end

local function handle_reject_cause(device, session, reject_cause)
	if reject_cause == 50 or reject_cause == 51 then
		local profile = M.get_profile(device, session.profile_id)
		if reject_cause == 50 then
			runtime.log:info("Changed PDP type to IPv4 for session %d", session.session_id)
			profile.pdptype = 'ipv4'
		elseif reject_cause == 51 then
			runtime.log:info("Changed PDP type to IPv6 for session %d", session.session_id)
			profile.pdptype = 'ipv6'
		end
	end
	session.reject_cause = reject_cause
end

function M.handle_event(facility, event)
	runtime.log:debug("handling ubus event %s '%s'", facility, json.encode(event))

	if facility == "mobiled.network" then
		if event.interface and event.action then
			if not M.stats.interfaces[event.interface] then
				M.stats.interfaces[event.interface] = {}
			end
			M.stats.interfaces[event.interface][event.action] = (M.stats.interfaces[event.interface][event.action] or 0) + 1
		end
		return
	end

	-- Ignore events that do not have an event descriptor.
	if not event.event then
		return
	end

	-- Introduce a small delay before scanning for new devices as in some cases the
	-- device_connected event is received before the sysfs entries are created.
	if event.event == "device_connected" then
		scan_timer:set(SCAN_DELAY)
	end

	-- In case of USB devices, we get a hotplug event without device index
	-- but with a device description. Let's figure out which device it is
	if event.event == "device_disconnected" then
		for _, sm in ipairs(stateMachines) do
			if sm.device and sm.device.desc == event.dev_desc then
				sm:handle_event(event)
				return
			end
		end
		runtime.log:error('Received "%s" event for unknown device (%s)', event.event, tostring(event.dev_desc))
		return
	end

	local dev_idx = event.dev_idx
	if not dev_idx then
		if event.event ~= "device_connected" and event.event ~= "device_disconnected" and event.event ~= "platform_config_changed" then
			runtime.log:warning('Received event "%s" without dev_idx', event.event)
		end
		dev_idx = 1
	end

	if string.match(event.event, "session_") or
		event.event == "sim_removed" or
		event.event == "sms_received" or
		event.event == "network_deregistered" or
		event.event == "emergency_numbers_updated" or
		event.event == "radio_interface_changed" or
		event.event == "cgi_changed" or
		event.event == "ecgi_changed" or
		event.event == "location_area_code_changed" or
		event.event == "tracking_area_code_changed" then

		local device = M.get_device(dev_idx)
		if not device then
			runtime.log:error('Received event "%s" for unknown device', event.event)
			return
		end

		if event.event == "network_deregistered" then
			device.stats.network.deregistered = device.stats.network.deregistered + 1
			local cause = tonumber(event.reject_cause)
			if cause then
				local severity = errors.reject_cause_severity(cause)
				if severity == "warning" or severity == "error" or severity == "fatal" then
					errors.add_error(device, severity, "reject_cause", { reject_cause = cause, pdp_type = event.pdp_type, session_id = 0 })
				end
				handle_reject_cause(device, device:get_data_session(0), cause)
			end
			M.propagate_session_state(device, "disconnected", "ipv4v6", device:get_data_sessions())
		elseif event.event == "tracking_area_code_changed" then
			device.stats.network.tracking_area_code_changed = device.stats.network.tracking_area_code_changed + 1
		elseif event.event == "location_area_code_changed" then
			device.stats.network.location_area_code_changed = device.stats.network.location_area_code_changed + 1
		elseif event.event == "radio_interface_changed" then
			device.stats.network.radio_interface_changed = device.stats.network.radio_interface_changed + 1
		elseif event.event == "ecgi_changed" then
			device.stats.network.ecgi_changed = device.stats.network.ecgi_changed + 1
		elseif event.event == "cgi_changed" then
			device.stats.network.cgi_changed = device.stats.network.cgi_changed + 1
		elseif string.match(event.event, "session_") then
			local session = device:get_data_session(event.session_id)
			if session then
				if event.event == "session_disconnected" then
					local cause = tonumber(event.reject_cause)
					if cause then
						local severity = errors.reject_cause_severity(cause)
						if severity == "warning" or severity == "error" or severity == "fatal" then
							errors.add_error(device, severity, "reject_cause", { reject_cause = cause, pdp_type = event.pdp_type, session_id = event.session_id })
						end
						handle_reject_cause(device, session, cause)
					end
					session.stats.disconnected = session.stats.disconnected + 1
					M.propagate_session_state(device, "disconnected", event.pdp_type or "ipv4v6", { session })
				elseif event.event == "session_activate" then
					M.activate_data_session(device, event)
				elseif event.event == "session_config_changed" then
					session.changed = true
				elseif event.event == "session_deactivate" then
					session.stats.deactivated = session.stats.deactivated + 1
					M.deactivate_data_session(device, event.session_id)
				end
			else
				runtime.log:error('Received event "%s" for unknown data session', event.event)
			end
		elseif event.event == "sms_received" then
			sms.sync(device)
		elseif event.event == "emergency_numbers_updated" and event.numbers then
			device:set_emergency_numbers(event.numbers)
		elseif event.event == "sim_removed" then
			device.stats.sim.removed = device.stats.sim.removed + 1
		end
	end

	for _, sm in ipairs(stateMachines) do
		if sm.dev_idx == dev_idx then
			sm:handle_event(event)
			break
		end
	end
end

function M.apn_is_allowed(device, apn)
	if not apn then
		return true
	end
	local sim_info = device:get_sim_info()
	if not sim_info or not sim_info.access_control_list then
		return true
	end
	if sim_info.access_control_list.apn then
		for _ , acl_apn in pairs(sim_info.access_control_list.apn) do
			if acl_apn == apn then
				return true
			end
		end
	end
	return false
end

return M
