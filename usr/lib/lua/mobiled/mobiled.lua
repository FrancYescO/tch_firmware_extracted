---------------------------------
--! @file
--! @brief The mobiled module containing glue logic for the entire Mobiled
---------------------------------

local require, tostring = require, tostring
local table, pairs, ipairs = table, pairs, ipairs

local mobiled_statemachine = require('mobiled.statemachine')
local mobiled_plugin = require('mobiled.plugin')
local mobiled_device = require('mobiled.device')
local mobiled_ubus = require('mobiled.ubus')
local version = require('mobiled.version')
local errors = require('mobiled.error')
local signal = require("signal").signal

local M = {}

local runtime
local plugins = {}
local stateMachines = {}

local device_index = 1

function M.cleanup()
	runtime.log:info("Cleaning up...")
	for i=#stateMachines,1,-1 do
		local sm = stateMachines[i]
		if sm.device then
			M.stop_device(sm.device, false)
		end
		table.remove(stateMachines, i)
	end
	runtime.ubus:close()
	for i=#plugins,1,-1 do
		local p = plugins[i]
		p:destroy()
		table.remove(plugins, i)
	end
	runtime.uloop.cancel()
	runtime.log:info("Cleanup done")
	os.exit(1)
end

function M.reloadconfig()
	runtime.log:info("Reloading config")
	runtime.config.reloadconfig(stateMachines, plugins)
end

function M.init(rt)
	runtime = rt

	M.platform = require('mobiled.platform')
	M.platform.init(runtime)
	local ret, errMsg = mobiled_ubus.init(runtime)
	if not ret then
		return nil, errMsg
	end

	signal("SIGTERM", function() M.cleanup() end)
	signal("SIGINT", function() M.cleanup() end)
	signal("SIGHUP", function() M.reloadconfig(); return true end)
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
	return false
end

function M.add_device(params)
	if M.device_exists(params.dev_desc) then
		return nil, "Device " .. tostring(params.dev_desc).." was already added"
	end

	local sm
	for _, s in ipairs(stateMachines) do
		if not s.device then
			sm = s
			break
		end
	end
	
	if not sm then return nil, "No statemachine available to add device" end

	local c = M.get_config()

	local plugin, errMsg = load_plugin(params.plugin_name, { tracelevel = c.tracelevel })
	if not plugin then return nil, errMsg end

	local device
	params.dev_idx = sm.dev_idx
	device, errMsg = mobiled_device.create(runtime, params, plugin)
	if not device then return nil, errMsg end

	sm.device = device
	sm.device.sm = sm

	runtime.events.send_event("mobiled", { event = "device_added", dev_idx = sm.dev_idx, dev_desc = sm.device.desc })

	M.start_new_statemachine()
	return device
end

function M.stop_device(device, force)
	if not force then
		M.stop_all_data_sessions(device)
	end
	local sessions = device:get_data_sessions() or {}
	M.propagate_session_state(device, "disconnected", sessions)
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
	for _, sm in ipairs(stateMachines) do
		sm.dev_idx = device_index
		device_index = device_index + 1
	end
	M.start_new_statemachine()
end

function M.get_device(dev_idx)
	for _, sm in ipairs(stateMachines) do
		if sm.device and (sm.dev_idx == dev_idx or not dev_idx) then
			return sm.device
		end
	end
	return nil, "No device found with index " .. tostring(dev_idx)
end

function M.get_device_by_imei(imei)
	for _, sm in ipairs(stateMachines) do
		if sm.device and sm.device.info.imei == imei then
			return sm.device
		end
	end
	return nil, "No device found with IMEI " .. tostring(imei)
end

function M.get_device_by_desc(desc)
	for _, sm in ipairs(stateMachines) do
		if sm.device and (sm.device.desc == desc or not desc) then
			return sm.device
		end
	end
	return nil, "No device found with description " .. tostring(desc)
end

function M.get_devices()
	local devices = {}
	for _, sm in ipairs(stateMachines) do
		if sm.device then
			table.insert(devices, sm.device)
		end
	end
	return devices
end

function M.get_device_count()
	local devices = 0
	for _, sm in ipairs(stateMachines) do
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
	for _, p in ipairs(plugins) do
		if p.name == name then
			return p
		end
	end
	return nil, "No plugin found with name " .. tostring(name)
end

function M.get_profile(id)
	-- Check if the profile we want to use is a reused device profile
	if string.match(id, "device") then
		return { id = id }
	end
	return runtime.config.get_profile(id)
end

function M.activate_data_session(device, session_id, profile_id, interface, optional)
	local log, events = runtime.log, runtime.events
	-- Check if the profile we want to use is a reused device profile
	local dev_profile_id = string.match(profile_id, "^device:(.*)$")
	local ret, errMsg
	if dev_profile_id then
		local profiles = device:get_profile_info()
		ret, errMsg = nil, "No such profile " .. profile_id
		if type(profiles) == "table" and type(profiles.profiles) == "table" then
			for _, profile in pairs(profiles.profiles) do
				if tostring(profile.id) == dev_profile_id then
					ret = true
					break
				end
			end
		end
	else
		ret, errMsg = runtime.config.get_profile(profile_id)
	end
	if ret then
		local c = M.get_config()
		ret, errMsg = device:activate_data_session(session_id, profile_id, interface, optional, c.pdn_retry_timer_value)
		if ret then
			log:info("Activated data session " .. tostring(session_id) .. " using profile " .. tostring(profile_id) .. " on interface " .. interface)
			events.send_event("mobiled", { event = "session_setup", session_id = session_id, dev_idx = device.sm.dev_idx, interface = interface })
		else
			if errMsg then log:warning(errMsg) end
		end
	else
		if errMsg then log:warning(errMsg) end
	end
end

function M.deactivate_data_session(device, session_id, interface)
	local log, events = runtime.log, runtime.events
	local ret, errMsg = device:deactivate_data_session(session_id, interface)
	if ret then
		events.send_event("mobiled", { event = "session_teardown", session_id = session_id, dev_idx = device.sm.dev_idx, interface = interface })
	else
		if errMsg then log:warning(errMsg) end
	end
end

function M.remove_data_session(device, session_id)
	local log, events = runtime.log, runtime.events
	local ret, errMsg = device:remove_data_session(session_id)
	if ret then
		events.send_event("mobiled", { event = "session_removed", session_id = session_id, dev_idx = device.sm.dev_idx })
	else
		if errMsg then log:warning(errMsg) end
	end
end

function M.start_data_session(device, session_id, profile, interface)
	M.propagate_session_state(device, "setup", { device:get_data_session(session_id) })
	return device:start_data_session(session_id, profile, interface)
end

function M.stop_data_session(device, session_id, interface)
	-- We need this teardown event here in order to kill the PPP interface otherwise the state will never change to disconnected
	M.propagate_session_state(device, "teardown", { device:get_data_session(session_id) })
	return device:stop_data_session(session_id, interface)
end

function M.stop_all_data_sessions(device)
	local sessions = device:get_data_sessions()
	for _, session in pairs(sessions) do
		M.propagate_session_state(device, "teardown", { session })
		device:stop_data_session(session.session_id)
	end
end

function M.get_data_session(device, session_id)
	local session, errMsg = device:get_data_session(session_id)
	return session or nil, errMsg
end

function M.register_network(device)
	local params = M.get_device_config(device)
	device:register_network(params.network)
end

function M.get_config()
	return runtime.config.get_config()
end

function M.get_device_config(device)
	return runtime.config.get_device_config(device)
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
	if not iccid then return nil, "Invalid ICCID" end
	local config = M.get_config()
	if config and config.store_pin then
		return runtime.config.store_pin_to_config(pinType, pin, iccid)
	end
end

function M.unlock_pin_from_config(device, pinType, iccid)
	local pin = M.get_pin_from_config(pinType, iccid)
	if pin then
		local ret, errMsg = device:unlock_pin(pinType, pin)
		if not ret then
			M.remove_pin_from_config(pinType, iccid)
			return ret, errMsg
		end
		return true
	end
	return nil, "No PIN stored in config"
end

function M.propagate_session_state(device, session_state, sessions)
	for _, session in pairs(sessions) do
		runtime.events.send_event("mobiled", { dev_idx = device.sm.dev_idx, dev_desc = device.desc, event = "session_state_changed", session_state = session_state, session_id = session.session_id })
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

function M.get_version()
	return version.version()
end

function M.add_error(device, severity, error_type, error_message)
	errors.add_error(device, severity, error_type, error_message)
end

function M.handle_event(event)
	if(event.event == "timeout") then
		for _, sm in ipairs(stateMachines) do
			if sm.dev_idx == event.dev_idx then
				sm:handle_event(event)
			end
		end
	else
		if event.event == "device_disconnected" then
			-- In case of USB devices, we get a hotplug event without device index
			-- Let's figure out which device it is
			if not event.dev_idx then
				for _, sm in ipairs(stateMachines) do
					if sm.device and sm.device.desc == event.dev_desc then
						sm:handle_event(event)
					end
				end
				return
			end
		end

		local dev_idx = event.dev_idx
		if not dev_idx then
			if event.event ~= "device_connected" and event.event ~= "device_disconnected" then
				runtime.log:info('Received event without device index "' .. event.event .. '"')
			end
			dev_idx = 1
		end

		if event.event == "network_deregistered" and event.reject_cause then
			local device = M.get_device(event.dev_idx)
			if not device then
				runtime.log:error('Event "' .. event.event .. '" for unknown device')
				return
			end

			local severity = errors.reject_cause_severity(event.reject_cause)
			if severity == "warning" or severity == "error" or severity == "fatal" then
				errors.add_error(device, severity, "reject_cause", {reject_cause = event.reject_cause, pdp_type = event.pdp_type })
			end
		end

		if string.match(event.event, "session_") then
			local device = M.get_device(event.dev_idx)
			if not device then
				runtime.log:error('Event "' .. event.event .. '" for unknown device')
				return
			end

			if event.event == "session_disconnected" and event.reject_cause then
				local severity = errors.reject_cause_severity(event.reject_cause)
				if severity == "warning" or severity == "error" or severity == "fatal" then
					errors.add_error(device, severity, "reject_cause", {reject_cause = event.reject_cause, pdp_type = event.pdp_type })
				end
			elseif event.event == "session_config_changed" or event.event == "session_activate" then
				if event.event == "session_activate" then
					M.activate_data_session(device, event.session_id, event.profile_id, event.interface, event.optional)
				end
				local session = device:get_data_session(event.session_id)
				if session then
					if event.event == "session_config_changed" then
						session.changed = true
					end
					-- Create the default context for the PDN with which we attach
					if session.session_id == 0 and (session.changed or not session.default_context_created) then
						local profile = M.get_profile(session.profile_id)
						if profile then
							runtime.log:info("Configuring attach context")
							if device:create_default_context(profile) then
								session.default_context_created = true
							end
						end
					end
				end
			elseif event.event == "session_deactivate" then
				M.deactivate_data_session(device, event.session_id, event.interface)
			end
		end

		for _, sm in ipairs(stateMachines) do
			if sm.dev_idx == dev_idx then
				sm:handle_event(event)
				break
			end
		end
	end
end

return M
