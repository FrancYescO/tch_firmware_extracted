local table, unpack, setmetatable, string, pairs, os, tostring, type = table, unpack, setmetatable, string, pairs, os, tostring, type

local qmidev = require("libqmi.device")
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

	local device = qmidev.create(runtime, params, plugin_config.tracelevel or 6)
	device.id = get_device_id()
	table.insert(devices, device)
	return device.id
end

function M.init_device(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local ret
	ret, errMsg = run_action(dev_idx, "init_device")

	-- Use global PDH to disable autoconnect
	device:send_command("--stop-network 4294967295 --autoconnect")

	if ret then device.state.initialized = true end
	if device.state.initialized then
		device:send_event("mobiled", { event = "device_initialized", dev_idx = device.dev_idx })
	end
	return ret, errMsg
end

function M.destroy_device(dev_idx, force)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	runtime.log:info("Destroy device " .. dev_idx)
	
	for i=#device.interfaces,1,-1 do
		local intf = device.interfaces[i]
		if intf.channel then
			intf:close()
		end
		table.remove(device.interfaces, i)
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
	local info = {}
	run_action(dev_idx, "get_ip_info", info, session_id)
	return info
end

local function get_device_info(device, info)
	local ret
	
	if not device.buffer.device_info.imei then
		device.buffer.device_info.imei = device:send_command("--get-imei")
	end

	if not device.buffer.device_info.software_version then
		ret = device:get_revision()
		if ret then device.buffer.device_info.software_version = ret end
	end

	if not device.buffer.device_info.hardware_version then
		ret = device:get_hardware_revision()
		if ret then device.buffer.device_info.hardware_version = ret end
	end

	if not device.buffer.device_info.manufacturer then
		ret = device:get_manufacturer()
		if ret then device.buffer.device_info.manufacturer = ret end
	end

	if not device.buffer.device_info.model then
		ret = device:get_model()
		if ret then device.buffer.device_info.model = ret end
		if device.buffer.device_info.model == "0" and device.buffer.device_info.manufacturer == "QUALCOMM INCORPORATED" and device.buffer.device_info.software_version then
			ret = string.match(device.buffer.device_info.software_version, "^([%d%u]+)%-")
			if ret then device.buffer.device_info.model = ret end
		end
	end

	info.power_mode = device.state.powermode or "online"

	for k, v in pairs(device.buffer.device_info) do info[k] = v end

	info.initialized = device.state.initialized
	info.vid = device.vid
	info.pid = device.pid
end

function M.get_device_info(dev_idx)
	local info = {}
	run_action(dev_idx, "get_device_info", info)
	return info
end

local function get_device_capabilities(device, info)
	if not device.buffer.device_capabilities.radio_interfaces then
		local radio_interfaces = {}

		table.insert(radio_interfaces, { radio_interface = "auto" })

		local ret = device:send_command("--get-capabilities")
		if type(ret) == "table" then
			if type(ret.networks) == "table" then
				for _, radio in pairs(ret.networks) do
					table.insert(radio_interfaces, { radio_interface = radio })
				end
			end
		end
		device.buffer.device_capabilities.radio_interfaces = radio_interfaces
	end

	info.radio_interfaces = device.buffer.device_capabilities.radio_interfaces
	info.sms_reading = true
	info.sms_sending = true
	info.reuse_profiles = false
	info.manual_plmn_selection = true
	info.arfcn_selection_support = ""
	info.band_selection_support = ""
	info.strongest_cell_selection = false
	info.max_data_sessions = #device.sessions
end

function M.get_device_capabilities(dev_idx)
	local info = {}
	run_action(dev_idx, "get_device_capabilities", info)
	return info
end

local function get_radio_signal_info(device, info)
	local ret = device:send_command("--get-signal-info")
	if type(ret) == "table" then
		info.radio_interface = ret.type
		info.rssi = ret.rssi
		info.rsrq = ret.rsrq
		info.rsrp = ret.rsrp
		info.ecio = ret.ecio
	end
end

function M.get_radio_signal_info(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	if device.state.powermode == "lowpower" then return nil, "Not available" end

	local info = {}
	run_action(dev_idx, "get_radio_signal_info", info)
	return info
end

local function get_network_info(device, info)
	local ret = device:send_command("--get-serving-system")
	if type(ret) == "table" then
		if ret.registration == "registered" then info.nas_state = "registered"
		elseif ret.registration == "searching" then info.nas_state = "not_registered_searching"
		elseif ret.registration == "denied" then info.nas_state = "registration_denied" end

		if ret.roaming == true then
			info.roaming_state = "roaming"
		else
			info.roaming_state = "home"
		end

		if ret.plmn_mcc then
			info.plmn_info = {}
			info.plmn_info.description = ret.plmn_description
			info.plmn_info.mcc = ret.plmn_mcc
			info.plmn_info.mnc = string.format("%03d", ret.plmn_mnc)
		end
	end
end
	
function M.get_network_info(dev_idx)
	local info = {
		nas_state = "not_registered"
	}
	setmetatable(info, { __index = function() return "" end })
	run_action(dev_idx, "get_network_info", info)
	return info
end

local function get_session_info(device, info, session_id)
	local ret = device:send_command("--get-data-status")
	if ret == "disconnected" then
		info.session_state = "disconnected"
		device:clear_session_cid(session_id)
		device:set_session_data_handle(session_id, nil)
	elseif ret == "connected" then
		info.session_state = "connected"
		if device.session_state[session_id+1] then
			info.duration = device.session_state[session_id+1].duration
		end
	end
end

function M.get_profile_info(dev_idx)
	return {}
end

function M.get_session_info(dev_idx, session_id)
	local info = {
		session_state = "disconnected"
	}
	run_action(dev_idx, "get_session_info", info, session_id)

	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	if not info.proto then
		info.proto = device.sessions[session_id+1].proto
	end

	return info
end

local function get_sim_info(device, info)
	local ret = device:send_command("--get-pin-status")
	if ret then
		if ret.error == "uim_uninitialized" then
			info.sim_state = "not_present"
		else
			if ret.pin1_status == "disabled" or ret.pin1_status == "verified" then
				info.sim_state = "ready"
			elseif ret.pin1_status == "not_verified" then
				info.sim_state = "locked"
			elseif ret.pin1_status == "blocked" then
				info.sim_state = "blocked"
			else
				info.sim_state = "not_present"
			end
		end
	end

	if not device.buffer.sim_info.iccid then
		ret = device:send_command("--get-iccid")
		if type(ret) == "string" then
			device.buffer.sim_info.iccid = ret
		end
	end

	if info.sim_state == "ready" then
		if not device.buffer.sim_info.imsi then
			ret = device:send_command("--get-imsi")
			if type(ret) == "string" then
				device.buffer.sim_info.imsi = ret
			end
		end
		if not device.buffer.sim_info.msisdn and not device.msisdn_not_provisioned then
			ret = device:send_command("--get-msisdn")
			if type(ret) == "table" then
				if ret.error == "not_provisioned" then
					device.msisdn_not_provisioned = true
				end
			else
				device.buffer.sim_info.msisdn = ret
			end
		end
	end
	info.imsi = device.buffer.sim_info.imsi
	info.iccid = device.buffer.sim_info.iccid
	info.msisdn = device.buffer.sim_info.msisdn
end

function M.get_sim_info(dev_idx)
	local info = {}
	run_action(dev_idx, "get_sim_info", info)
	return info
end

local function get_pin_info(device, info, pin_type)
	local ret = device:send_command("--get-pin-status")
	if ret then
		local t = "1"
		if pin_type == "pin2" then t = "2" end

		local status = ret["pin" .. t .. "_status"]
		if status == "disabled" then info.pin_state = "disabled"
		elseif status == "not_verified" then info.pin_state = "enabled_not_verified"
		elseif status == "blocked" then info.pin_state = "blocked"
		elseif status == "verified" then info.pin_state = "enabled_verified" end
		info.unlock_retries_left = ret["pin" .. t .. "_verify_tries"]
		info.unblock_retries_left = ret["pin" .. t .. "_unblock_tries"]
	end
end

function M.get_pin_info(dev_idx, pin_type)
	local info = {
		pin_state = "unknown"
	}
	run_action(dev_idx, "get_pin_info", info, pin_type)
	return info
end

function M.unlock_pin(dev_idx, pin_type, pin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local t = "1"
	if pin_type == "pin2" then t = "2" end

	local ret = device:send_command("--verify-pin" .. t .. " " .. pin)
	if ret then return true end
	return nil
end

function M.unblock_pin(dev_idx, pin_type, puk, newpin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local t = "1"
	if pin_type == "pin2" then t = "2" end

	if device:send_command("--unblock-pin" .. t .. " --puk " .. puk .. " --new-pin " .. newpin) then return true end
	return nil
end

function M.enable_pin(dev_idx, pin_type, pin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local t = "1"
	if pin_type == "pin2" then t = "2" end

	if device:send_command("--set-pin" .. t .. "-protection enabled --pin " .. pin) then return true end
	return nil
end

function M.disable_pin(dev_idx, pin_type, pin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local t = "1"
	if pin_type == "pin2" then t = "2" end

	if device:send_command("--set-pin" .. t .. "-protection disabled --pin " .. pin) then return true end
	return nil
end

function M.change_pin(dev_idx, pin_type, pin, newpin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local t = "1"
	if pin_type == "pin2" then t = "2" end

	if device:send_command("--change-pin" .. t .. " --pin " .. pin .. " --new-pin " .. newpin) then return true end
	return nil
end

local function start_data_session(device, session_id, profile)
	local cid
	if device.session_state[session_id+1] then
		if device.session_state[session_id+1].data_handle then
			return nil, "Data session " .. session_id .. "is already running"
		end
		if device.session_state[session_id+1].cid then
			cid = device.session_state[session_id+1].cid
		end
	end

	local apn = profile.apn or ""
	local command = '--start-network "' .. apn .. '"'
	if profile.authentication and profile.username and profile.password then
		local authentication
		if profile.authentication == "pap" or profile.authentication == "chap" then
			authentication = profile.authentication
		else
			authentication = "both"
		end
		command = command .. " --auth-type " .. authentication .. " --username " .. profile.username .. " --password " .. profile.password
	end

	if profile.pdp_type == "ipv4" then
		command = command .. " --ip-family ipv4"
	elseif profile.pdp_type == "ipv6" then
		command = command .. " --ip-family ipv6"
	end

	if not cid then
		device.session_state[session_id+1].cid = device:send_command("--get-client-id wds")
		cid = device.session_state[session_id+1].cid
		if not cid then return nil, "Failed to start data session" end
	end

	command = command .. " --set-client-id wds," .. cid

	local data_handle
	-- When in UMTS or GSM mode, the start-network command takes longer then the default 2 seconds timeout
	local ret = device:send_command(command, 10)
	if type(ret) == "table" then
		if ret.error == "call_failed" then
			device:send_event("mobiled", { event = "network_deregistered", dev_idx = device.dev_idx })
		end
	else
		data_handle = ret
		if not cid and not data_handle then
			return nil, "Failed to start data session"
		end
	end
	if cid and not data_handle then
		runtime.log:warning("Releasing client ID " .. cid)
		device:clear_session_cid(session_id)
		return nil, "Failed to start data session"
	end

	helper.sleep(5)
	device.session_state[session_id+1] = {
		data_handle = data_handle,
		cid = cid,
		duration = 0
	}
	device:send_event("mobiled", { event = "session_connected", session_id = session_id, dev_idx = device.dev_idx })
end

function M.start_data_session(dev_idx, session_id, profile)
	return run_action(dev_idx, "start_data_session", session_id, profile)
end

local function stop_data_session(device, session_id)
	if device.session_state[session_id+1] then
		local data_handle = device.session_state[session_id+1].data_handle
		local cid = device.session_state[session_id+1].cid
		if data_handle and cid then
			runtime.log:info("Stopping data session " .. data_handle .. " with CID " .. cid)
			local ret = device:send_command("--set-client-id wds," .. cid .. " --stop-network " .. data_handle)
			if ret and device:clear_session_cid(session_id) then
				device:set_session_data_handle(session_id, nil)
				return
			end
		end
	else
		runtime.log:error("No session information for session " .. session_id)
	end
end

function M.stop_data_session(dev_idx, session_id)
	return run_action(dev_idx, "stop_data_session", session_id)
end

local function register_network(device, network_config)
	if device.reg_info.nas_state ~= "registered" then
		device.reg_info.nas_state = "not_registered"
		get_network_info(device, device.reg_info)
	end
	local selected_radio = {
		priority = 10,
		type = "auto"
	}
	for _, radio in pairs(network_config.radio_pref) do
		if radio.priority < selected_radio.priority then
			selected_radio.priority = radio.priority
			selected_radio.type = radio.type
		end
	end

	local command = "--set-network-modes "
	if selected_radio.type == "lte" then
		command = command .. 'lte'
		device:send_command("--set-network-preference auto")
	elseif selected_radio.type == "umts" then
		command = command .. 'umts'
		device:send_command("--set-network-preference wcdma")
	elseif selected_radio.type == "gsm" then
		command = command .. 'gsm'
		device:send_command("--set-network-preference gsm")
	else
		command = command .. 'all'
		device:send_command("--set-network-preference auto")
	end
	device:send_command(command)

	if network_config.roaming == true then
		device:send_command("--set-network-roaming any")
	else
		device:send_command("--set-network-roaming off")
	end

	command = "--network-register "
	if network_config.selection_pref == "manual" and network_config.mcc and network_config.mnc then
		device:send_command("--set-plmn --mcc " .. network_config.mcc .. " --mnc " .. network_config.mnc)
	else
		if device.reg_info.nas_state == "registered" then
			command = command .. "--reg_mcc " .. device.reg_info.plmn_info.mcc .. " --reg_mnc " .. device.reg_info.plmn_info.mnc .. " --reg_radio " .. selected_radio.type
		end
	end

	device:send_command(command)
	if device.reg_info.nas_state == "registered" then
		device.reg_info.nas_state = "not_registered"
		get_network_info(device, device.reg_info)
		if device.reg_info.nas_state ~= "registered" then
			device:send_command("--set-device-operating-mode offline")
			device:send_command("--set-device-operating-mode reset")
		end
	end
end

function M.register_network(dev_idx, network_config)
	return run_action(dev_idx, "register_network", network_config)
end

local function find_entry(entries, mcc, mnc)
	for _, network in pairs(entries) do
		if network.plmn_info.mcc == tostring(mcc) and network.plmn_info.mnc == tostring(mnc) then
			return network
		end
	end
	return nil
end

function M.network_scan(dev_idx, start)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	if start then
		helper.sleep(5)
		device:send_command("--network-register")
		helper.sleep(5)

		device.scanresults = { scanning = true }
		local start_time = os.time()

		local ret
		local retries = 10
		while type(ret) ~= "table" do
			ret = device:send_command("--network-scan", 300)
			if type(ret) ~= "table" then
				runtime.log:info("Retry scan in 10 seconds")
				helper.sleep(10)
				retries = retries - 1
				if retries == 0 then break end
			end
		 end

		local duration = os.difftime(os.time(), start_time)
		local network_scan_list = {}
		if ret and type(ret) == "table" then
			if type(ret.network_info) == "table" then
				for _, network in pairs(ret.network_info) do
					local entry = find_entry(network_scan_list, network.mcc, network.mnc)
					if not entry then
						entry = { plmn_info = { mcc = tostring(network.mcc), mnc = tostring(network.mnc) } }
						table.insert(network_scan_list, entry)
					end
					entry.plmn_info.description = network.description
					entry.roaming_state = "home"
					entry.preferred = true
					entry.forbidden = false
					entry.used = false
					for _, status in pairs(network.status) do
						if status == "current_serving" then
							entry.used = true
						elseif status == "forbidden" then
							entry.forbidden = true
						elseif status == "preferred" then
							entry.preferred = true
						elseif status == "roaming" then
							entry.roaming_state = "roaming"
						end
					end
				end
			end
			if type(ret.radio_access_technology) == "table" then
				for _, radio in pairs(ret.radio_access_technology) do
					local entry = find_entry(network_scan_list, radio.mcc, radio.mnc)
					if not entry then
						entry = { plmn_info = { mcc = tostring(radio.mcc), mnc = tostring(radio.mnc) } }
						table.insert(network_scan_list, entry)
					end
					entry.radio_interface = radio.radio
				end
			end
		end
		device.scanresults.duration = duration
		device.scanresults.network_scan_list = network_scan_list
		device.scanresults.scanning = false
	end
	if device.scanresults then
		return device.scanresults
	end
	return { scanning = false }
end

function M.send_sms(dev_idx, number, message)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	if device:send_command('--send-message "' .. message .. '" --send-message-target "' .. number .. '"') then return true end
	return nil
end

function M.delete_sms(dev_idx, message_id)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	if device:send_command('--delete-message ' .. message_id) then return true end
	return nil
end

function M.set_sms_status(dev_idx, message_id, status)
	return nil, "Not supported"
end

function M.get_sms_info(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local messages = 0
	local ret = device:send_command("--list-messages")
	if type(ret) == "table" then
		for _, message_id in pairs(ret) do
			messages = messages + 1
		end
	end

	return { read_messages = messages, unread_messages = 0, max_messages = 255 }
end

function M.get_sms_messages(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local messages = {}
	local ret = device:send_command("--list-messages")
	if type(ret) == "table" then
		for _, message_id in pairs(ret) do
			local message = device:send_command("--get-message " .. message_id)
			if type(message) == "table" then
				table.insert(messages, { text = message.text, number = message.sender, date = message.timestamp, status = "read", id = message_id })
			end
		end
	end
	return { messages = messages }
end

function M.reconfigure_plugin(config)
	return true
end

local function set_power_mode(device, mode)
	if mode == "lowpower" then
		device.buffer.session_info = {}
		if device:send_command("--set-device-operating-mode=low_power") then return true end
	elseif mode == "online" then
		if device:send_command("--set-device-operating-mode=online") then return true end
	end
	return nil
end

function M.set_power_mode(dev_idx, mode)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	device.state.powermode = mode

	return run_action(dev_idx, "set_power_mode", mode)
end

function M.periodic(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	for _, session in pairs(device.session_state) do
		if session.data_handle and session.cid then
			session.duration = session.duration + 1
		end
	end
	return true
end

function M.create_default_context(profile)
	return true
end

function M.debug(dev_idx)
	return run_action(dev_idx, "debug")
end

function M.firmware_upgrade(dev_idx, path)
	return nil, "Not supported"
end

function M.get_firmware_upgrade_info(dev_idx)
	return { status = "not_running" }
end

M.mappings = {
	get_device_info = get_device_info,
	get_device_capabilities = get_device_capabilities,
	get_radio_signal_info = get_radio_signal_info,
	get_network_info = get_network_info,
	get_session_info = get_session_info,
	get_sim_info = get_sim_info,
	get_pin_info = get_pin_info,
	start_data_session = start_data_session,
	stop_data_session = stop_data_session,
	register_network = register_network,
	set_power_mode = set_power_mode
}

return M
