local table, pairs, unpack, setmetatable, string, tonumber, os = table, pairs, unpack, setmetatable, string, tonumber, os

local sms = require("libat.sms")
local sim = require("libat.sim")
local atdevice = require("libat.device")
local network = require("libat.network")
local session = require("libat.session")
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
	for k, device in pairs(devices) do
		if device.desc == params.dev_desc then
			return k
		end
	end

	local device, errMsg = atdevice.create(runtime, params, plugin_config.tracelevel or 6)
	if not device then return nil, errMsg end

	device.id = get_device_id()
	table.insert(devices, device)
	return device.id
end

local function init_device(device)
	if device:probe() then
		device:send_event("mobiled", { event = "device_initialized", dev_idx = device.dev_idx })
		sms.init(device)
		return true
	end
	return nil, "Failed to initialize control channel"
end

function M.init_device(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	-- Always execute this, not overwritable by extension
	local ret
	ret, errMsg = init_device(device)
	if ret then
		ret, errMsg = run_action(dev_idx, "init_device")
		if ret then
			device.state.initialized = true
		end
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

function M.get_profile_info(dev_idx)
	return {}
end

local function get_device_info(device, info)
	local ret = device:send_singleline_command('AT+CFUN?', '+CFUN:')
	if ret then
		local mode = tonumber(string.match(ret, "+CFUN:%s?(%d+)"))
		if mode == 1 then
			info.power_mode = "online"
		elseif mode == 0 then
			info.power_mode = "lowpower"
		end
	end

	if not device.buffer.device_info.imei then
		ret = device:send_singleline_command("AT+CGSN", "")
		if ret and helper.isnumeric(ret) then
			device.buffer.device_info.imei = ret
		end
	end

	if not device.buffer.device_info.software_version then
		ret = device:get_revision()
		if ret then device.buffer.device_info.software_version = ret end
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
	info.sms_reading = false
	info.sms_sending = false
	local ret = device:send_singleline_command('AT+CSMS=0', "+CSMS:")
	if ret then
		local mt, mo = string.match(ret, "+CSMS:%s?(%d+),%s?(%d+)")
		if mt == "1" then
			info.sms_reading = true
		end
		if mo == "1" then
			info.sms_sending = true
		end
	end
	info.reuse_profiles = false
	info.manual_plmn_selection = true
	info.arfcn_selection_support = ""
	info.band_selection_support = ""
	info.strongest_cell_selection = false
	info.cs_voice_support = false
	info.volte_support = false
	info.max_data_sessions = #device.sessions
	local types = session.get_supported_pdp_types(device)
	local supported_pdp_types = {}
	for k in pairs(types) do
		table.insert(supported_pdp_types, k)
	end
	info.supported_pdp_types = table.concat(supported_pdp_types, " ")
end

function M.get_device_capabilities(dev_idx)
	local info = {}
	run_action(dev_idx, "get_device_capabilities", info)
	return info
end

local function get_radio_signal_info(device, info)
	local ret = device:send_singleline_command('AT+CSQ', "+CSQ:")
	if ret then
		local rssi, ber = string.match(ret, "+CSQ:%s?(%d+),%s?(%d+)")
		rssi = tonumber(rssi)
		if rssi then
			if rssi == 0 then
				info.rssi = -113
			elseif rssi == 1 then
				info.rssi = -111
			elseif rssi == 31 then
				info.rssi = -51
			elseif rssi ~= 99 then
				info.rssi = (((56-(rssi-2))*-1)-53)
			end
		end
		ber = tonumber(ber)
		if ber then
			if ber == 0 then
				info.ber = 0.14
			elseif ber == 1 then
				info.ber = 0.28
			elseif ber == 2 then
				info.ber = 0.57
			elseif ber == 3 then
				info.ber = 1.13
			elseif ber == 4 then
				info.ber = 2.26
			elseif ber == 5 then
				info.ber = 4.53
			elseif ber == 6 then
				info.ber = 9.05
			elseif ber == 7 then
				info.ber = 18.10
			end
		end
	end

	info.radio_interface = network.get_radio_interface(device)
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
	local area_code, act
	info.nas_state, area_code, info.cell_id, act = network.get_state(device)
	if act == "gsm" or act == "umts" then
		info.location_area_code = area_code
	else
		info.tracking_area_code = area_code
	end
	info.ps_state = network.get_ps_state(device)
	local plmn = network.get_plmn(device)
	if plmn then
		info.plmn_info = {
			mcc = plmn.mcc,
			mnc = plmn.mnc,
			description = plmn.description
		}
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

function M.get_time_info(dev_idx)
	local info = {}
	run_action(dev_idx, "get_time_info", info)
	return info
end

local function get_session_info(device, info, session_id)
	if device.sessions[session_id+1] and device.sessions[session_id+1].proto ~= "ppp" then
		info.session_state = session.get_state(device, session_id)
	end
end

function M.get_session_info(dev_idx, session_id)
	local info = {
		session_state = "disconnected"
	}
	run_action(dev_idx, "get_session_info", info, session_id)

	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	if not info.proto and device.sessions[session_id+1] then
		info.proto = device.sessions[session_id+1].proto
	end

	if info.proto == "ppp" then
		for _, i in pairs(device.interfaces) do
			if i.type == "modem" then
				info.ppp = {
					device = i.port
				}
				break
			end
		end
	end

	return info
end

local function get_sim_info(device, info)
	info.sim_state = sim.get_state(device)
	info.iccid_before_unlock = true
	if not device.buffer.sim_info.iccid then
		device.buffer.sim_info.iccid = sim.get_iccid(device)
	end
	info.iccid = device.buffer.sim_info.iccid
	if info.sim_state == "ready" then
		if not device.buffer.sim_info.imsi then
			device.buffer.sim_info.imsi = sim.get_imsi(device)
		end
		if not device.buffer.sim_info.msisdn then
			device.buffer.sim_info.msisdn = sim.get_msisdn(device)
		end
		if not device.buffer.sim_info.preferred_plmn then
			device.buffer.sim_info.preferred_plmn = sim.get_preferred_plmn(device)
		end
		if not device.buffer.sim_info.forbidden_plmn then
			device.buffer.sim_info.forbidden_plmn = sim.get_forbidden_plmn(device)
		end
		info.imsi = device.buffer.sim_info.imsi
		info.msisdn = device.buffer.sim_info.msisdn
		info.preferred_plmn = device.buffer.sim_info.preferred_plmn
		info.forbidden_plmn = device.buffer.sim_info.forbidden_plmn
	end
end

function M.get_sim_info(dev_idx)
	local info = {}
	run_action(dev_idx, "get_sim_info", info)
	return info
end

local function get_pin_info(device, info, t)
	local sim_state = sim.get_state(device)
	if sim_state == "locked" then info.pin_state = "enabled_not_verified" end
	if sim_state == "blocked" then info.pin_state = "blocked" end
	if sim_state == "ready" then info.pin_state = "enabled_verified" end

	local pin_enabled = sim.get_locking_facility(device, 'SC')
	if pin_enabled ~= nil then
		if pin_enabled == false then info.pin_state = "disabled" end
	end
end

function M.get_pin_info(dev_idx, t)
	local info = {
		pin_state = "unknown"
	}
	run_action(dev_idx, "get_pin_info", info, t)

	if tonumber(info.unlock_retries_left) == 0 and tonumber(info.unblock_retries_left) == 0 then
		info.pin_state = "permanently_blocked"
	end
	return info
end

function M.unlock_pin(dev_idx, t, pin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	return sim.unlock(device, pin)
end

function M.unblock_pin(dev_idx, t, puk, newpin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	return sim.unblock(device, puk, newpin)
end

function M.enable_pin(dev_idx, t, pin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	return sim.enable_pin(device, pin)
end

function M.disable_pin(dev_idx, t, pin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	return sim.disable_pin(device, pin)
end

function M.change_pin(dev_idx, t, pin, newpin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	return sim.change_pin(device, pin, newpin)
end

function M.start_data_session(dev_idx, session_id, profile)
	return run_action(dev_idx, "start_data_session", session_id, profile)
end

function M.stop_data_session(dev_idx, session_id)
	return run_action(dev_idx, "stop_data_session", session_id)
end

local function register_network(device, network_config)
	M.set_power_mode(device.id, "online")

	-- Enable network registration events
	local ret = device:send_command("AT+CREG=2")
	if not ret then
		-- Some handsets in tethered mode don't support CREG=2
		device:send_command("AT+CREG=1")
	end

	local cops_command = "AT+COPS="
	if network_config.selection_pref == "manual" and network_config.mcc and network_config.mnc then
		cops_command = cops_command .. '1,2,"' .. network_config.mcc .. network_config.mnc .. '"'
	else
		cops_command = cops_command .. '0,,'
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

	if selected_radio.type == "lte" then
		cops_command = cops_command .. ',7'
	elseif selected_radio.type == "umts" then
		cops_command = cops_command .. ',2'
	elseif selected_radio.type == "gsm" then
		cops_command = cops_command .. ',0'
	end

	ret = device:send_command(cops_command, (60*1000))
	if not ret then
		device:send_command('AT+COPS=0', (60*1000))
	end
end

function M.register_network(dev_idx, network_config)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	device.buffer.network_info = {}
	device.buffer.radio_signal_info = {}
	return run_action(dev_idx, "register_network", network_config)
end

local function network_scan(device, start)
	if start then
		device.scanresults = { scanning = true }
		local start_time = os.time()
		local ret = device:send_singleline_command('AT+COPS=?', '+COPS:', (5*60*1000), 3)
		local duration = os.difftime(os.time(), start_time)
		local network_scan_list = {}
		if ret then
			for section in string.gmatch(ret, '%((%d,".-",".-",".-",%d,?)%)') do
				local entry = {}
				local stat, description, plmn, radio_interface = string.match(section, '(%d),"(.-)",".-","([0-9]-)",(%d)')
				if stat == "2" then
					entry.roaming_state = "home"
					entry.preferred = true
					entry.forbidden = false
					entry.used = true
				elseif stat == "1" then
					entry.roaming_state = "roaming"
					entry.preferred = false
					entry.forbidden = false
					entry.used = false
				elseif stat == "3" then
					entry.roaming_state = "roaming"
					entry.preferred = false
					entry.forbidden = true
					entry.used = false
				end
				entry.plmn_info = {}
				if plmn then
					entry.plmn_info.mcc = string.sub(plmn, 1, 3)
					entry.plmn_info.mnc = string.sub(plmn, 4)
				end
				entry.plmn_info.description = description
				radio_interface = tonumber(radio_interface)

				if radio_interface >= 0 and radio_interface <= 3 and radio_interface ~= 2 then
					entry.radio_interface = "gsm"
				elseif radio_interface == 2 or (radio_interface >= 4 and radio_interface <= 6) then
					entry.radio_interface = "umts"
				elseif radio_interface == 7 then
					entry.radio_interface = "lte"
				else
					entry.radio_interface = "no_service"
				end
				table.insert(network_scan_list, entry)
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

function M.network_scan(dev_idx, start)
	return run_action(dev_idx, "network_scan", start)
end

function M.send_sms(dev_idx, number, message)
	return run_action(dev_idx, "send_sms", number, message)
end

function M.delete_sms(dev_idx, message_id)
	return run_action(dev_idx, "delete_sms", message_id)
end

function M.set_sms_status(dev_idx, message_id, status)
	return nil, "Not supported"
end

function M.get_sms_info(dev_idx)
	return run_action(dev_idx, "get_sms_info")
end

function M.get_sms_messages(dev_idx)
	return run_action(dev_idx, "get_sms_messages")
end

function M.reconfigure_plugin(config)
	if config and config.tracelevel then
		for _, device in pairs(devices) do
			for _, interface in pairs(device.interfaces) do
				if interface.interface then
					interface.interface:set_tracelevel(config.tracelevel)
				end
			end
		end
	end
	return true
end

local function set_power_mode(device, mode)
	if mode == "lowpower" or mode == "airplane" then
		device.buffer.session_info = {}
		device.buffer.network_info = {}
		device.buffer.radio_signal_info = {}
		return device:send_command('AT+CFUN=0', 5000)
	end
	return device:send_command('AT+CFUN=1', 5000)
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
	device:get_unsolicited_messages()
	return true
end

local function create_default_context(device, profile)
	local pdptype, errMsg = session.get_pdp_type(device, profile.pdptype)
	if not pdptype then
		return nil, errMsg
	end
	local apn = profile.apn or ""
	device:send_command(string.format('AT+CGDCONT=1,"%s","%s"', pdptype, apn))
end

function M.create_default_context(dev_idx, profile)
	return run_action(dev_idx, "create_default_context", profile)
end

local function string_starts(data, pattern)
	return string.sub(data,1,string.len(pattern))==pattern
end

local function execute_command(device, command)
	if string_starts(command, "AT") or string_starts(command, "at") then
		local ret, errMsg, cmeError = device:send_multiline_command(command, "", 10000)
		-- device:send_multiline_command will return nil when it fails to match an intermediate line
		-- and set errMsg to "invalid response". We assume this actually returned "OK"
		if not ret then
			if errMsg == "invalid response" then
				ret = { "OK" }
			elseif errMsg == "cme error" then
				if cmeError == "non cme error" then
					ret = { "ERROR" }
				else
					ret = { cmeError }
				end
			end
		end
		if ret then
			return table.concat(ret, "\n")
		end
	end
	return nil, 'Invalid command: "' .. command .. '"'
end

function M.execute_command(dev_idx, command)
	return run_action(dev_idx, "execute_command", command)
end

local function debug(device)
	local ret = device:send_multiline_command('AT+CGDCONT?', '+CGDCONT:')
	if ret then
		for _, line in pairs(ret) do
			table.insert(device.debug.device_state, line)
		end
	end
	ret = device:send_singleline_command('AT+CPMS=?', '+CPMS:')
	if ret then
		table.insert(device.debug.device_state, ret)
	end
	ret = device:send_singleline_command('AT+CSCA?', '+CSCA:')
	if ret then
		table.insert(device.debug.device_state, ret)
	end
end

function M.debug(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	device.debug = { device_state = {} }
	run_action(dev_idx, "debug")
	local debug_path = "/tmp/mobiled.dump"
	local file = io.open(debug_path, "a")
	file:write("\n\n*********** LIBAT ***********\n\n")
	file:close()
	helper.twrite(devices, debug_path, true)
	return device.debug
end

function M.firmware_upgrade(dev_idx, path)
	return run_action(dev_idx, "firmware_upgrade", path)
end

function M.get_firmware_upgrade_info(dev_idx)
	local ret = run_action(dev_idx, "get_firmware_upgrade_info")
	if type(ret) == "table" then return ret end
	return { status = "not_running" }
end

function M.dial(dev_idx, number)
	return run_action(dev_idx, "dial", number)
end

function M.end_call(dev_idx, call_id)
	return run_action(dev_idx, "end_call", call_id)
end

function M.accept_call(dev_idx, call_id)
	return run_action(dev_idx, "accept_call", call_id)
end

function M.call_info(dev_idx, call_id)
	return run_action(dev_idx, "call_info", call_id)
end

function M.multi_call(dev_idx, call_id, action)
	return run_action(dev_idx, "multi_call", call_id, action)
end

function M.supplementary_service(dev_idx, service, action, forwarding_type, forwarding_number)
	return run_action(dev_idx, "supplementary_service", service, action, forwarding_type, forwarding_number)
end

function M.get_network_interface(dev_idx, session_id)
	local ret = run_action(dev_idx, "get_network_interface", session_id)
	if type(ret) == "string" then
		return ret
	end
end

M.mappings = {
	create_default_context = create_default_context,
	get_device_info = get_device_info,
	get_device_capabilities = get_device_capabilities,
	get_radio_signal_info = get_radio_signal_info,
	get_network_info = get_network_info,
	get_session_info = get_session_info,
	get_sim_info = get_sim_info,
	get_pin_info = get_pin_info,
	start_data_session = session.start,
	stop_data_session = session.stop,
	register_network = register_network,
	set_power_mode = set_power_mode,
	network_scan = network_scan,
	execute_command = execute_command,
	get_sms_messages = sms.get_messages,
	delete_sms = sms.delete,
	get_sms_info = sms.info,
	send_sms = sms.send,
	debug = debug
}

return M
