local table, unpack, type = table, unpack, type

local ubus = require("ubus")
local dev = require("libwebapi.device")
local helper = require("mobiled.scripthelpers")

local devices = {}
local runtime = {}
local plugin_config = {}
local M = {}

local function get_device(dev_idx)
	for _, device in pairs(devices) do
		if device.id == dev_idx then
			return device
		end
	end
	return nil, "No such device"
end

local function get_device_id()
	local id = 1
	while true do
		local before = id
		for _, device in pairs(devices) do
			if device.id == id then
				id = id + 1
			end
		end
		if before == id then return id end
	end
end

local function run_action(dev_idx, action, ...)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local mapping_function
	local t = "augment"
	if device.mapper then
		mapping_function = device.mapper[action]
		if device.mapper.mappings and device.mapper.mappings[action] then
			t = device.mapper.mappings[action]
		end
	end

	local ret
	if mapping_function and (t == "override" or t == "runfirst") then
		ret, errMsg = mapping_function(device.mapper, device, unpack(arg))
		if t == "override" then
			return ret, errMsg
		end
	end

	if M.mappings[action] then
		ret, errMsg = M.mappings[action](device, unpack(arg))
		if t ~= "augment" or mapping_function == nil then
			return ret, errMsg
		end
	end

	if mapping_function then
		return mapping_function(device.mapper, device, unpack(arg))
	end
	return true
end

function M.init_plugin(rt, config)
	runtime = rt
	plugin_config = config or {}
	return true
end

function M.destroy_plugin()
	return true
end

function M.add_device(params)
	for k, device in ipairs(devices) do
		if device.desc == params.dev_desc then
			return k
		end
	end

	local device = dev.create(runtime, params, plugin_config.tracelevel or 6)
	device.id = get_device_id()
	table.insert(devices, device)

	if type(params.network_interfaces) == "table" then
		local conn = ubus.connect()
		if conn then
			conn:call("network", "add_dynamic", { name = "libwebapi_control" .. device.id, proto = "dhcp", ifname = params.network_interfaces[1], reqopts = "1 3 33 42 51", defaultroute = false })
		end
	end
	return device.id
end

local function get_gateway_ip()
	local conn = ubus.connect()
	local data = helper.getUbusData(conn, "network.interface.libwebapi_control1", "status", {})
	if data and type(data.route) == "table" then
		for _, route in pairs(data.route) do
			if type(route) == "table" then
				if route.target and route.target ~= "0.0.0.0" then
					return route.target
				end
			end
		end
	end
	return nil, "No gateway IP found"
end

function M.init_device(dev_idx, device_desc)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local retries = 5
	while retries > 0 do
		local ip = get_gateway_ip()
		if ip then
			device.web_info.ip = ip
			break
		end
		helper.sleep(2)
		retries = retries - 1
	end

	local ret
	ret, errMsg = run_action(dev_idx, "init_device")
	if not ret then return nil, errMsg end

	retries = 10
	while retries > 0 do
		local info = M.get_device_info(dev_idx)
		if info and info.device_config_parameter and info[info.device_config_parameter] then
			device.state.initialized = true
			break
		end
		helper.sleep(1)
		retries = retries - 1
	end

	if retries == 0 then return nil, "Timeout reading device info" end

	if device.state.initialized then
		device:send_event("mobiled", { event = "device_initialized", dev_idx = device.dev_idx })
	end
	return ret, errMsg
end

function M.destroy_device(dev_idx, force)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	runtime.log:info("Destroy device " .. dev_idx)

	local conn = ubus.connect()
	if conn then
		conn:call("network.interface", "remove", { interface = "libwebapi_control" .. device.id })
	end
	for i=#devices,1,-1 do
		local d = devices[i]
		if d.id == dev_idx then
			table.remove(devices, i)
			break
		end
	end
	return true
end

function M.get_ip_info(dev_idx, session_id)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	
	local info = {}
	run_action(dev_idx, "get_ip_info", info, session_id)
	helper.merge_tables(info, device.buffer.ip_info)
	return info
end

local function get_device_info(device, info)
	info.initialized = device.state.initialized
	info.vid = device.vid
	info.pid = device.pid
	helper.merge_tables(info, device.buffer.device_info)
end

function M.get_device_info(dev_idx)
	local info = {}
	run_action(dev_idx, "get_device_info", info)
	return info
end

local function get_device_capabilities(device, info)
	info.sms_reading = false
	info.sms_sending = false
	info.reuse_profiles = false
	info.manual_plmn_selection = false
	info.arfcn_selection_support = ""
	info.band_selection_support = ""
	info.strongest_cell_selection = false
	info.max_data_sessions = 1
	helper.merge_tables(info, device.buffer.device_capabilities)
end

function M.get_device_capabilities(dev_idx)
	local info = {}
	run_action(dev_idx, "get_device_capabilities", info)
	return info
end

function M.get_radio_signal_info(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local info = {}
	run_action(dev_idx, "get_radio_signal_info", info)
	helper.merge_tables(info, device.buffer.radio_signal_info)
	return info
end

function M.get_time_info(dev_idx)
	local info = {}
	run_action(dev_idx, "get_time_info", info)
	return info
end

function M.get_network_info(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local info = {}
	run_action(dev_idx, "get_network_info", info)
	helper.merge_tables(info, device.buffer.network_info)
	return info
end

function M.get_profile_info(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local info = {}
	run_action(dev_idx, "get_profile_info", info)
	helper.merge_tables(info, device.buffer.profile_info)
	return info
end

function M.get_session_info(dev_idx, session_id)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local info = {}
	run_action(dev_idx, "get_session_info", info, session_id)
	helper.merge_tables(info, device.buffer.session_info)
	return info
end

function M.get_sim_info(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local info = {}
	run_action(dev_idx, "get_sim_info", info)
	helper.merge_tables(info, device.buffer.sim_info)
	return info
end

function M.get_pin_info(dev_idx, pin_type)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local info = {}
	run_action(dev_idx, "get_pin_info", info, pin_type)
	helper.merge_tables(info, device.buffer.pin_info)
	return info
end

function M.unlock_pin(dev_idx, pin_type, pin)
	return run_action(dev_idx, "unlock_pin", pin_type, pin)
end

function M.unblock_pin(dev_idx, pin_type, puk, newpin)
	return run_action(dev_idx, "unblock_pin", pin_type, puk, newpin)
end

function M.enable_pin(dev_idx, pin_type, pin)
	return run_action(dev_idx, "enable_pin", pin_type, pin)
end

function M.disable_pin(dev_idx, pin_type, pin)
	return run_action(dev_idx, "disable_pin", pin_type, pin)
end

function M.change_pin(dev_idx, pin_type, pin, newpin)
	return run_action(dev_idx, "change_pin", pin_type, pin, newpin)
end

function M.start_data_session(dev_idx, session_id, profile)
	return run_action(dev_idx, "start_data_session", session_id, profile)
end

function M.stop_data_session(dev_idx, session_id)
	return run_action(dev_idx, "stop_data_session", session_id)
end

function M.register_network(dev_idx, network_config)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	device.buffer.network_info = {}
	device.buffer.radio_signal_info = {}
	return run_action(dev_idx, "register_network", network_config)
end

function M.network_scan(dev_idx, start)
	return run_action(dev_idx, "network_scan", start) or {}
end

function M.send_sms(dev_idx, number, message)
	return nil, "Not supported"
end

function M.delete_sms(dev_idx, message_id)
	return nil, "Not supported"
end

function M.set_sms_status(dev_idx, message_id, status)
	return nil, "Not supported"
end

function M.get_sms_info(dev_idx)
	return nil, "Not supported"
end

function M.get_sms_messages(dev_idx)
	return nil, "Not supported"
end

function M.reconfigure_plugin(config)
	return true
end

local function set_power_mode(device, mode)
	if mode == "lowpower" then
		device.buffer.session_info = {}
		device.buffer.network_info = {}
		device.buffer.radio_signal_info = {}
	end
	return true
end

function M.set_power_mode(dev_idx, mode)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	device.state.powermode = mode

	return run_action(dev_idx, "set_power_mode", mode)
end

function M.periodic(dev_idx)
	return run_action(dev_idx, "periodic")
end

function M.create_default_context(profile)
	return true
end

function M.debug(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	device.debug = { device_state = {} }
	run_action(dev_idx, "debug")
	return device.debug
end

function M.firmware_upgrade(dev_idx, path)
	return nil, "Not supported"
end

function M.get_firmware_upgrade_info(dev_idx)
	return { status = "not_running" }
end

function M.get_errors(dev_idx)
	return run_action(dev_idx, "get_errors") or {}
end

function M.login(dev_idx, username, password)
	return run_action(dev_idx, "login", username, password)
end

M.mappings = {
	get_device_info = get_device_info,
	get_device_capabilities = get_device_capabilities,
	set_power_mode = set_power_mode
}

return M
