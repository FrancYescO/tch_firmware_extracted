---------------------------------
--! @file
--! @brief The implementation of the UBUS handler functions
---------------------------------

local tinsert = table.insert

local leds
local runtime = {}
local ubus = require('ubus')
local helper = require("mobiled.scripthelpers")

local M = {}

local error_messages = {
	no_device = "No such device",
	not_ready = "Not ready",
	invalid_params = "Invalid parameters"
}
setmetatable(error_messages, { __index = function() return "Unknown error" end })

local function mobiled_get_status(req, msg)
	local conn = runtime.ubus
	local dev_idx = msg.dev_idx
	local mobiled = runtime.mobiled

	local status = mobiled.get_state(dev_idx)
	local display_status = mobiled.get_display_state(dev_idx)

	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		if not status then
			conn:reply(req, { error = error_messages.invalid_params })
		else
			conn:reply(req, { status = status, display_status = display_status, version = mobiled.get_version(), devices = mobiled.get_device_count() })
		end
		return
	end

	local data_session_requests = {}
	for _, session in pairs(device:get_data_sessions()) do
		local s = {
			session_id = session.session_id,
			activated = session.activated
		}
		tinsert(data_session_requests, s)
	end

	local response = {
		data_session_requests = data_session_requests,
		status = status,
		display_status = display_status,
		version = mobiled.get_version(),
		plugin = device:get_plugin_name(),
		devices = mobiled.get_device_count(),
		uptime = helper.uptime() - mobiled.started_uptime
	}
	conn:reply(req, response)
end

local function mobiled_reload(_, msg)
	runtime.mobiled.reloadconfig(msg.force)
end

local function mobiled_stop()
	runtime.uloop.cancel()
end

local function mobiled_get_devices(req)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	local response = {
		devices = {}
	}

	local devices = mobiled.get_devices()
	for _, d in pairs(devices) do
		local data = d:get_device_info() or {}
		tinsert(response.devices, {dex_idx = d.sm.dev_idx, dev_desc = data.dev_desc, imei = data.imei })
	end
	conn:reply(req, response)
end

local function get_session_info(device, session)
	local sessionInfo = device:get_session_info(session.session_id)
	if not sessionInfo then
		return {}
	end

	local session_params = {
		"session_id",
		"optional",
		"bridge",
		"allowed",
		"internal",
		"autoconnect",
		"activated",
		"name"
	}

	if not session.internal then
		tinsert(session_params, "changed")
		tinsert(session_params, "interface")
	end

	for _, param in pairs(session_params) do
		sessionInfo[param] = session[param]
	end

	sessionInfo.profile = session.profile_id

	-- Workaround for 64 bit numbers in UBUS Lua wrapper
	if sessionInfo.packet_counters then
		if sessionInfo.packet_counters.tx_bytes then
			sessionInfo.packet_counters.tx_bytes = tostring(sessionInfo.packet_counters.tx_bytes)
		end
		if sessionInfo.packet_counters.rx_bytes then
			sessionInfo.packet_counters.rx_bytes = tostring(sessionInfo.packet_counters.rx_bytes)
		end
	end
	if sessionInfo.duration then
		sessionInfo.duration = tostring(sessionInfo.duration)
	end

	-- Check if a PDN retry timer is running
	if session.pdn_retry_timer.timer then
		sessionInfo.pdn_retry_timer_remaining = math.floor(session.pdn_retry_timer.timer:remaining()/1000)
		sessionInfo.pdn_retry_timer_value = session.pdn_retry_timer.value
		sessionInfo.reject_cause = session.reject_cause
	end
	return sessionInfo
end

local function mobiled_get_session_info(req, msg)
	local mobiled, conn = runtime.mobiled, runtime.ubus
	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if msg.session_id then
		local session = mobiled.get_data_session(device, msg.session_id)
		if session then
			conn:reply(req, get_session_info(device, session))
		end
	else
		local sessions = {}
		for _, session in pairs(device:get_data_sessions()) do
			tinsert(sessions, get_session_info(device, session))
		end
		conn:reply(req, { sessions = sessions })
	end
end

local function mobiled_get_profile_info(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	local data = device:get_profile_info() or {}
	conn:reply(req, data)
end

local function mobiled_get_network_info(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	local data = device:get_network_info(msg.max_age) or {}

	-- Check if the attach retry timer is running
	if device.attach_retry_timer.timer then
		data.attach_retry_timer_remaining = math.floor(device.attach_retry_timer.timer:remaining()/1000)
		data.attach_retry_timer_value = device.attach_retry_timer.value
	end

	conn:reply(req, data)
end

local function mobiled_get_time_info(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	local data = device:get_time_info() or {}
	conn:reply(req, data)
end

local function mobiled_network_scan(req, msg)
	local conn = runtime.ubus
	local events = runtime.events
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if msg.start then
		events.send_event("mobiled", { event = "network_scan_start", dev_idx = dev_idx })
		return
	end
	local data = device:network_scan(false) or {}
	conn:reply(req, data)
end

local firmware_upgrade_start_statuses = {
	not_running = true,
	invalid_parameters = true,
	timeout = true,
	failed = true,
	done = true
}

local function mobiled_firmware_upgrade(req, msg)
	local conn = runtime.ubus
	local events = runtime.events
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if msg.path and firmware_upgrade_start_statuses[device.info.firmware_upgrade.status] then
		device.info.firmware_upgrade.path = msg.path
		events.send_event("mobiled", { event = "firmware_upgrade_start", dev_idx = dev_idx })
		return
	end

	local data = device:get_firmware_upgrade_info() or {}
	conn:reply(req, data)
end

local function mobiled_get_device_info(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	local device
	if msg.imei then
		device = mobiled.get_device_by_imei(msg.imei)
	elseif msg.dev_desc then
		device = mobiled.get_device_by_desc(msg.dev_desc)
	else
		device = mobiled.get_device(msg.dev_idx)
	end
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	local data
	if msg.imei or msg.dev_desc then
		data = { dev_idx = device.sm.dev_idx }
	else
		data = device:get_device_info() or {}
	end

	if data.temperature then
		data.temperature = string.format("%.1f", data.temperature)
	end
	conn:reply(req, data)
end

local function mobiled_get_device_stats(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end
	conn:reply(req, device:get_device_stats() or {})
end

local function mobiled_get_device_capabilities(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	local device_capabilities = device:get_device_capabilities() or {}
	if device_capabilities.radio_interfaces then
		local supported_modes = {}
		for _, radio in pairs(device_capabilities.radio_interfaces) do
			tinsert(supported_modes, radio.radio_interface)
			if radio.supported_bands then
				device_capabilities["supported_bands_"..radio.radio_interface] = table.concat(radio.supported_bands, " ")
			end
		end
		device_capabilities.supported_modes = table.concat(supported_modes, " ")
		device_capabilities.radio_interfaces = nil
	end
	conn:reply(req, device_capabilities)
end

local function mobiled_get_device_radio_preferences(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	local radio_preferences = {}
	local device_capabilities = device:get_device_capabilities()
	if device_capabilities and device_capabilities.radio_interfaces then
		local supported_modes = {}
		for _, radio in pairs(device_capabilities.radio_interfaces) do
			supported_modes[radio.radio_interface] = true
		end
		for _, radio_preference in ipairs(runtime.config.get_radio_preferences()) do
			if radio_preference.name and radio_preference.radios then
				local is_supported = false
				for _, radio in pairs(radio_preference.radios) do
					-- Radios can be qualified with a '?' to indicate that the radio should be omitted
					-- from the radio preference if it is not supported by the device and not that the
					-- radio preference should omitted entirely if the radio is not supported.
					local name, qualifier = radio:match("^(.-)(%??)$")
					if supported_modes[name] then
						is_supported = true
					elseif qualifier ~= "?" then
						is_supported = false
						break
					end
				end
				if is_supported then
					tinsert(radio_preferences, {name = radio_preference.name, radios = table.concat(radio_preference.radios, " ")})
				end
			end
		end
		if #radio_preferences == 0 then
			for _, radio in pairs(device_capabilities.radio_interfaces) do
				tinsert(radio_preferences, {name = radio.radio_interface, radios = radio.radio_interface})
			end
		end
	end

	conn:reply(req, {radio_preferences = radio_preferences})
end

local function mobiled_get_sim_info(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end
	local data = device:get_sim_info() or {}
	conn:reply(req, data)
end

local function mobiled_get_pin_info(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end
	local data = device:get_pin_info(msg.type or "pin1") or {}
	conn:reply(req, data)
end

local function mobiled_unlock_pin(req, msg)
	local conn = runtime.ubus
	if not msg.pin then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local mobiled = runtime.mobiled
	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if not device.iccid then
		conn:reply(req, { error = error_messages.not_ready })
		return
	end

	local pinType = msg.type or "pin1"
	local ret, errMsg = device:unlock_pin(pinType, msg.pin)
	if not ret then
		local data = device:get_pin_info(pinType) or {}
		conn:reply(req, { pin_info = data, error = errMsg })
		return
	end

	mobiled.store_pin_to_config(pinType, msg.pin, device.iccid)
	runtime.events.send_event("mobiled", { event = "pin_unlocked", dev_idx = device.sm.dev_idx, type = pinType })
end

local function mobiled_unblock_pin(req, msg)
	local conn = runtime.ubus
	if not msg.puk or not msg.newpin then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local mobiled = runtime.mobiled
	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if not device.iccid then
		conn:reply(req, { error = error_messages.not_ready })
		return
	end

	local pinType = msg.type or "pin1"
	local ret, errMsg = device:unblock_pin(pinType, msg.puk, msg.newpin)
	if not ret then
		local data = device:get_pin_info(pinType) or {}
		conn:reply(req, { pin_info = data, error = errMsg })
		return
	end

	mobiled.store_pin_to_config(pinType, msg.newpin, device.iccid)
	runtime.events.send_event("mobiled", { event = "pin_unblocked", dev_idx = device.sm.dev_idx, type = pinType })
end

local function __mobiled_enable_pin(req, msg, enable)
	local conn = runtime.ubus
	if not msg.pin then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local mobiled = runtime.mobiled
	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if not device.iccid then
		conn:reply(req, { error = error_messages.not_ready })
		return
	end

	local pinType = msg.type or "pin1"

	local ret, errMsg, event
	if enable then
		event = "pin_enabled"
		ret, errMsg = device:enable_pin(pinType, msg.pin)
	else
		event = "pin_disabled"
		ret, errMsg = device:disable_pin(pinType, msg.pin)
	end
	if not ret then
		local data = device:get_pin_info(pinType) or {}
		conn:reply(req, { pin_info = data, error = errMsg })
		return
	end

	mobiled.store_pin_to_config(pinType, msg.pin, device.iccid)
	runtime.events.send_event("mobiled", { event = event, dev_idx = device.sm.dev_idx, type = pinType })
end

local function mobiled_enable_pin(req, msg)
	return __mobiled_enable_pin(req, msg, true)
end

local function mobiled_disable_pin(req, msg)
	return __mobiled_enable_pin(req, msg, false)
end

local function mobiled_clear_pin()
	runtime.mobiled.clear_pin()
end

local function mobiled_change_pin(req, msg)
	local conn = runtime.ubus
	if not msg.pin or not msg.newpin then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local mobiled = runtime.mobiled
	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if not device.iccid then
		conn:reply(req, { error = error_messages.not_ready })
		return
	end

	local pinType = msg.type or "pin1"

	local ret, errMsg = device:change_pin(pinType, msg.pin, msg.newpin)
	if not ret then
		local data = device:get_pin_info(pinType) or {}
		conn:reply(req, { pin_info = data, error = errMsg })
		return
	end

	mobiled.store_pin_to_config(pinType, msg.newpin, device.iccid)
	runtime.events.send_event("mobiled", { event = "pin_changed", dev_idx = device.sm.dev_idx, type = pinType })
end

local function mobiled_get_radio_signal_info(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end
	local data = device:get_radio_signal_info(msg.max_age) or {}
	helper.floats_to_string(data)
	conn:reply(req, data)
end

local function mobiled_get_leds(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end
	conn:reply(req, leds.get_led_info(device))
end

local function mobiled_get_sms_info(req)
	local conn = runtime.ubus
	local ret, errMsg = runtime.mobiled.get_sms_info()
	if not ret then
		return conn:reply(req, { error = errMsg })
	end
	conn:reply(req, ret)
end

local function mobiled_get_sms_messages(req)
	local conn = runtime.ubus
	local ret, errMsg = runtime.mobiled.get_sms_messages()
	if not ret then
		return conn:reply(req, { error = errMsg })
	end
	conn:reply(req, {messages = ret})
end

local function mobiled_set_sms_status(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	if(not msg.id or not msg.status or (msg.status ~= "read" and msg.status ~= "unread")) then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local ret, errMsg = mobiled.set_sms_status(msg.id, msg.status)
	if not ret then
		return conn:reply(req, { error = errMsg })
	end
end

local function mobiled_delete_sms(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	if(not msg.id) then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local ret, errMsg = mobiled.delete_sms(msg.id)
	if not ret then
		return conn:reply(req, { error = errMsg })
	end
end

local function mobiled_send_sms(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	if(not msg.message or not msg.number) then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	local network_info = device:get_network_info(msg.max_age) or {}
	if network_info.nas_state ~= "registered" then
		return conn:reply(req, { error = "Network not registered" })
	end

	local ret, errMsg = device:send_sms(msg.number, msg.message)
	if not ret then
		return conn:reply(req, { error = errMsg })
	end
end

local function mobiled_debug(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled

	local debug_path = "/tmp/mobiled.dump"
	local file = io.open(debug_path, "w")
	file:write("\n\n*********** GLOBAL TABLE ***********\n\n")
	file:close()
	helper.twrite(_G, debug_path, true)
	file = io.open(debug_path, "a")
	file:write("\n\n*********** MOBILED STATEMACHINES ***********\n\n")
	file:close()
	helper.twrite(mobiled.get_statemachines(), "/tmp/mobiled.dump", true)
	file = io.open(debug_path, "a")
	file:write("\n\n*********** MOBILED CONFIG ***********\n\n")
	file:close()
	helper.twrite(runtime.config.get_raw_config(), "/tmp/mobiled.dump", true)

	local device = mobiled.get_device(msg.dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end
	local ret = device:debug()
	if type(ret) == "table" then
		conn:reply(req, ret or {})
	end
end

local function mobiled_collectgarbage(req)
	local conn = runtime.ubus
	local before = string.format("%.2f", collectgarbage("count"))
	runtime.log:info("Memory usage before garbage collection: " .. before)
	collectgarbage()
	local after = string.format("%.2f", collectgarbage("count"))
	runtime.log:info("Memory usage after garbage collection: " .. after)
	local ret = {
		usage_before = before,
		usage_after = after
	}
	conn:reply(req, ret)
end

local function mobiled_qual(req, msg)
	local conn = runtime.ubus
	local events = runtime.events
	local dev_idx = msg.dev_idx or 1

	local device = runtime.mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if msg.enable == nil and msg.execute == nil then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	if msg.enable ~= nil then
		if msg.enable then
			events.send_event("mobiled", { event = "qualtest_start", dev_idx = dev_idx })
		else
			events.send_event("mobiled", { event = "qualtest_stop", dev_idx = dev_idx })
		end
	elseif msg.execute then
		local ret, errMsg = device:execute_command(msg.execute)
		if not ret then
			conn:reply(req, { error = errMsg })
			return
		else
			conn:reply(req, { response = ret })
		end
	end
end

local function mobiled_device_errors(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if msg.flush == true then
		device.errors = {}
		return
	end

	if not device.errors then device.errors = {} end
	helper.merge_tables(device.errors, device:get_errors())
	conn:reply(req, { errors = device.errors })
end

local function mobiled_voice_dial(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if not msg.number then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local ret, errMsg = device:dial(msg.number)
	if not ret and errMsg then
		conn:reply(req, { error = errMsg })
		return
	end
	if type(ret) == "table" then
		conn:reply(req, ret)
	end
end

local function mobiled_voice_end_call(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if not msg.call_id then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local ret, errMsg = device:end_call(msg.call_id)
	if not ret and errMsg then
		conn:reply(req, { error = errMsg })
	end
end

local function mobiled_voice_accept_call(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if not msg.call_id then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local ret, errMsg = device:accept_call(msg.call_id)
	if not ret and errMsg then
		conn:reply(req, { error = errMsg })
	end
end

local function mobiled_voice_call_info(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	local ret, errMsg = device:call_info(msg.call_id)
	if not ret and errMsg then
		conn:reply(req, { error = errMsg })
		return
	end
	if not msg.call_id then
		conn:reply(req, { calls = ret })
	else
		conn:reply(req, ret)
	end
end

local function mobiled_voice_multi_call(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if not msg.call_id or not msg.action then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local ret, errMsg = device:multi_call(msg.call_id, msg.action, msg.second_call_id)
	if not ret and errMsg then
		conn:reply(req, { error = errMsg })
	end
end

local function mobiled_voice_supplementary_service(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if not msg.service or not msg.action then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local ret, errMsg = device:supplementary_service(msg.service, msg.action, msg.forwarding_type, msg.forwarding_number)
	if not ret and errMsg then
		conn:reply(req, { error = errMsg })
		return
	end
	if msg.action == "query" then
		conn:reply(req, ret)
	end
end

local function mobiled_voice_send_dtmf(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	if not msg.tones then
		conn:reply(req, { error = error_messages.invalid_params })
		return
	end

	local ret, errMsg = device:send_dtmf(msg.tones, msg.interval, msg.duration)
	if not ret and errMsg then
		conn:reply(req, { error = errMsg })
		return
	end
end

local function mobiled_voice_info(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	conn:reply(req, device:get_voice_info() or {})
end

local function mobiled_voice_network_capabilities(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	conn:reply(req, device:get_voice_network_capabilities() or {})
end

local function mobiled_voice_convert_to_data_call(req, msg)
	local conn = runtime.ubus
	local mobiled = runtime.mobiled
	local dev_idx = msg.dev_idx or 1

	local device = mobiled.get_device(dev_idx)
	if not device then
		conn:reply(req, { error = error_messages.no_device })
		return
	end

	local ret, errMsg = device:convert_to_data_call(msg.call_id, msg.codec)
	if not ret and errMsg then
		conn:reply(req, { error = errMsg })
	end
end

local mobiled_methods = {
	['mobiled'] = {
		status = {
			mobiled_get_status, {}
		},
		devices = {
			mobiled_get_devices, {}
		},
		debug = {
			mobiled_debug, {}
		},
		reload = {
			mobiled_reload, { force = ubus.BOOLEAN }
		},
		stop = {
			mobiled_stop, {}
		},
		collectgarbage = {
			mobiled_collectgarbage, {}
		}
	}
}

local mobiled_network_methods = {
	['mobiled.network'] = {
		sessions = {
			mobiled_get_session_info, {dev_idx = ubus.INT32, session_id = ubus.INT32}
		},
		serving_system = {
			mobiled_get_network_info, {dev_idx = ubus.INT32, max_age = ubus.INT32}
		},
		time = {
			mobiled_get_time_info, {dev_idx = ubus.INT32}
		},
		scan = {
			mobiled_network_scan, {dev_idx = ubus.INT32, start = ubus.BOOLEAN}
		}
	}
}

local mobiled_radio_methods = {
	['mobiled.radio'] = {
		signal_quality = {
			mobiled_get_radio_signal_info, {dev_idx = ubus.INT32, max_age = ubus.INT32}
		}
	}
}

local mobiled_device_methods = {
	['mobiled.device'] = {
		get = {
			mobiled_get_device_info, {dev_idx = ubus.INT32, imei = ubus.STRING, dev_desc = ubus.STRING}
		},
		stats = {
			mobiled_get_device_stats, {dev_idx = ubus.INT32}
		},
		capabilities = {
			mobiled_get_device_capabilities, {dev_idx = ubus.INT32}
		},
		radio_preferences = {
			mobiled_get_device_radio_preferences, {dev_idx = ubus.INT32}
		},
		firmware_upgrade = {
			mobiled_firmware_upgrade, {dev_idx = ubus.INT32, path = ubus.STRING}
		},
		profiles = {
			mobiled_get_profile_info, {dev_idx = ubus.INT32}
		},
		qual = {
			mobiled_qual, {dev_idx = ubus.INT32, enable = ubus.BOOLEAN, execute = ubus.STRING}
		},
		errors = {
			mobiled_device_errors, {dev_idx = ubus.INT32, flush = ubus.BOOLEAN}
		}
	}
}

local mobiled_sim_methods = {
	['mobiled.sim'] = {
		get = {
			mobiled_get_sim_info, {dev_idx = ubus.INT32}
		}
	}
}

local mobiled_pin_methods = {
	['mobiled.sim.pin'] = {
		get = {
			mobiled_get_pin_info, {dev_idx = ubus.INT32, type = ubus.STRING}
		},
		unlock = {
			mobiled_unlock_pin, {dev_idx = ubus.INT32, type = ubus.STRING, pin = ubus.STRING}
		},
		unblock = {
			mobiled_unblock_pin, {dev_idx = ubus.INT32, type = ubus.STRING, puk = ubus.STRING, newpin = ubus.STRING}
		},
		enable = {
			mobiled_enable_pin, {dev_idx = ubus.INT32, type = ubus.STRING, pin = ubus.STRING}
		},
		disable = {
			mobiled_disable_pin, {dev_idx = ubus.INT32, type = ubus.STRING, pin = ubus.STRING}
		},
		change = {
			mobiled_change_pin, {dev_idx = ubus.INT32, type = ubus.STRING, pin = ubus.STRING, newpin = ubus.STRING}
		},
		clear = {
			mobiled_clear_pin, {}
		}
	}
}

local mobiled_sms_methods = {
	['mobiled.sms'] = {
		get = {
			mobiled_get_sms_messages, {}
		},
		info = {
			mobiled_get_sms_info, {}
		},
		set_status = {
			mobiled_set_sms_status, {id = ubus.INT32, status = ubus.STRING}
		},
		delete = {
			mobiled_delete_sms, {id = ubus.INT32}
		},
		send = {
			mobiled_send_sms, {dev_idx = ubus.INT32, number = ubus.STRING, message = ubus.STRING}
		}
	}
}

local mobiled_leds_methods = {
	['mobiled.leds'] = {
		get = {
			mobiled_get_leds, {}
		}
	}
}

local mobiled_voice_methods = {
	['mobiled.voice'] = {
		dial = {
			mobiled_voice_dial, {dev_idx = ubus.INT32, number = ubus.STRING}
		},
		end_call = {
			mobiled_voice_end_call, {dev_idx = ubus.INT32, call_id = ubus.INT32}
		},
		accept_call = {
			mobiled_voice_accept_call, {dev_idx = ubus.INT32, call_id = ubus.INT32}
		},
		call_info = {
			mobiled_voice_call_info, {dev_idx = ubus.INT32, call_id = ubus.INT32}
		},
		multi_call = {
			mobiled_voice_multi_call, {dev_idx = ubus.INT32, call_id = ubus.INT32, action = ubus.STRING, second_call_id = ubus.INT32}
		},
		supplementary_service = {
			mobiled_voice_supplementary_service, {dev_idx = ubus.INT32, service = ubus.STRING, action = ubus.STRING}
		},
		send_dtmf = {
			mobiled_voice_send_dtmf, {dev_idx = ubus.INT32, tones = ubus.STRING, interval = ubus.INT32, duration = ubus.INT32}
		},
		info = {
			mobiled_voice_info, {dev_idx = ubus.INT32}
		},
		network_capabilities = {
			mobiled_voice_network_capabilities, {dev_idx = ubus.INT32}
		},
		data_call = {
			mobiled_voice_convert_to_data_call, {dev_idx = ubus.INT32, call_id = ubus.INT32, codec = ubus.STRING}
		}
	}
}

local UbusConn = {}
UbusConn.__index = UbusConn

function UbusConn:reply(req, data)
	if self._ubus then
		self._ubus:reply(req, data)
	end
end

function UbusConn:add(method)
	if self._ubus then
		self._ubus:add(method)
	end
end

function UbusConn:call(facility, func, params)
	if self._ubus then
		return self._ubus:call(facility, func, params)
	end
end

function UbusConn:send(facility, data)
	if self._ubus then
		self._ubus:send(facility, data)
	end
end

function UbusConn:listen(events)
	if self._ubus then
		self._ubus:listen(events)
	end
end

function UbusConn:close()
	self._ubus = nil
end

function UbusConn:has_object(object)
	if self._ubus then
		local namespaces = self._ubus:objects()
		for _, n in ipairs(namespaces) do
			if n == object then
				return true
			end
		end
	end
	return false
end

function M.init(rt)
	runtime = rt
	local mobiled = runtime.mobiled

	if not runtime.ubus then
		local conn = {}
		conn._ubus = ubus.connect()
		if not conn._ubus then
			return nil, "Failed to connect to UBUS"
		end
		setmetatable(conn, UbusConn)

		if conn:has_object("mobiled") then
			runtime.log:error("Mobiled UBUS objects already present")
			return nil, "Failed to initialize UBUS"
		end

		conn:add(mobiled_methods)
		conn:add(mobiled_network_methods)
		conn:add(mobiled_radio_methods)
		conn:add(mobiled_device_methods)
		conn:add(mobiled_sim_methods)
		conn:add(mobiled_pin_methods)
		conn:add(mobiled_sms_methods)
		conn:add(mobiled_voice_methods)
		conn:add(mobiled.platform:get_ubus_methods())

		local status, m = pcall(require, "mobiled.plugins.leds")
		leds = status and m or nil
		if leds then
			conn:add(mobiled_leds_methods)
		end

		runtime.ubus = conn
	end
	return true
end

return M
