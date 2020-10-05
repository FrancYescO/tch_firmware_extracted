local sms = require("libat.sms")
local sim = require("libat.sim")
local voice = require("libat.voice")
local atdevice = require("libat.device")
local network = require("libat.network")
local session = require("libat.session")
local helper = require("mobiled.scripthelpers")
local ubus = require("ubus")

local devices = {}
local runtime = {}
local plugin_config = {}
local ubus_conn = nil
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

local function get_device_by_port(port)
	for _, device in pairs(devices) do
		for _, interface in pairs(device.interfaces) do
			if interface.port == port then
				return device
			end
		end
	end
	return nil, "No such device"
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
		ret, errMsg = mapping_function(device.mapper, device, ...)
		if t == "override" then
			return ret, errMsg
		end
	end

	if M.mappings[action] then
		ret, errMsg = M.mappings[action](device, ...)
		if t ~= "augment" or mapping_function == nil then
			return ret, errMsg
		end
	end

	if mapping_function then
		return mapping_function(device.mapper, device, ...)
	end
	return true
end

local function run_cacheable_action(dev_idx, cache_key, action, max_age, info, ...)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local cached_result = device.cache[cache_key]
	if cached_result and (not max_age or os.difftime(os.time(), cached_result.time) < max_age) and device:is_busy() then
		runtime.log:debug("Retrieving result of " .. action .. " for device " .. dev_idx .. " from cache")
		for key, value in pairs(cached_result.info) do
			info[key] = value
		end
		return cached_result.ret, cached_result.errMsg
	end

	local ret
	ret, errMsg = run_action(dev_idx, action, info, ...)
	device.cache[cache_key] = {
		ret = ret,
		errMsg = errMsg,
		info = info,
		time = os.time()
	}
	return ret, errMsg
end

local function handle_atchannel_event(message)
	local device = get_device_by_port(message.port)
	if device then
		run_action(device.dev_idx, "handle_event", message)
	end
end

function M.init_plugin(rt, config)
	runtime = rt
	plugin_config = config or {}

	-- Listen for ubus events on a separate channel so that the callback can be
	-- freed as soon as libat is no longer used.
	if not ubus_conn then
		ubus_conn = ubus.connect()
		if not ubus_conn then
			return nil, "Failed to connect to UBUS"
		end
	end
	ubus_conn:listen({
		["atchannel"] = handle_atchannel_event
	})

	return true
end

function M.destroy_plugin()
	if ubus_conn then
		ubus_conn:close()
		ubus_conn = nil
	end

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

	local ret = true
	if device:get_mode() == "normal" then
		-- Always execute this, not overwritable by extension
		ret, errMsg = init_device(device)
	end
	if ret then
		ret, errMsg = run_action(dev_idx, "init_device")
		if ret then
			device.state.initialized = true
		end
	end
	return ret, errMsg
end

local function destroy_device(device)
	-- Disable CREG and CGREG notifications
	return device:send_command("AT+CREG=0") and device:send_command("AT+CGREG=0")
end

function M.destroy_device(dev_idx, force) --luacheck: no unused args
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	runtime.log:notice("Destroy device " .. dev_idx)

	run_action(dev_idx, "destroy_device")

	for i=#device.interfaces,1,-1 do
		local intf = device.interfaces[i]
		if intf.interface then
			intf.interface:close()
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
	run_cacheable_action(dev_idx, "get_ip_info" .. session_id, "get_ip_info", nil, info, session_id)
	return info
end

local function get_profile_info(device, info)
	local profiles = {}
	local ret = device:send_multiline_command('AT+CGDCONT?', '+CGDCONT:')
	if ret then
		for _, line in pairs(ret) do
			local id, pdp, apn = string.match(line, '+CGDCONT: (%d+),"(.-)","(.-)"')
			if id then
				local pdptype = "ipv4"
				if pdp == "IPV4V6" then
					pdptype = "ipv4v6"
				elseif pdp == "IPV6" then
					pdptype = "ipv6"
				end
				table.insert(profiles, { name = "Profile " .. id, id = id, apn = apn, pdptype = pdptype, authentication = "none" })
			end
		end
	end
	info.profiles = profiles
end

function M.get_profile_info(dev_idx)
	local info = {}
	run_action(dev_idx, "get_profile_info", info)
	return info
end

local function get_device_info(device, info)
	local ret = device:send_singleline_command('AT+CFUN?', '+CFUN:')
	if ret then
		local mode = tonumber(string.match(ret, "+CFUN:%s?(%d+)"))
		if mode == 1 then
			info.power_mode = "online"
		elseif mode == 0 then
			info.power_mode = "lowpower"
		elseif mode == 4 then
			info.power_mode = "airplane"
		end
	end

	if not device.buffer.device_info.imei then
		ret = device:send_singleline_command("AT+CGSN", "")
		if tonumber(ret) then
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
	run_cacheable_action(dev_idx, "get_device_info", "get_device_info", nil, info)
	return info
end

local function get_device_capabilities(device, info)
	info.sms_reading = false
	info.sms_sending = false
	info.max_carriers = 1
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
	info.reuse_profiles = true
	info.manual_plmn_selection = true
	info.arfcn_selection_support = ""
	info.band_selection_support = ""
	info.strongest_cell_selection = false
	info.cs_voice_support = false
	info.volte_support = false
	info.max_data_sessions = #device.sessions
	info.supported_auth_types = "none"
	local types = session.get_supported_pdp_types(device)
	local supported_pdp_types = {}
	for k in pairs(types) do
		table.insert(supported_pdp_types, k)
	end
	info.supported_pdp_types = supported_pdp_types
end

function M.get_device_capabilities(dev_idx)
	local info = {}
	run_cacheable_action(dev_idx, "get_device_capabilities", "get_device_capabilities", nil, info)
	return info
end

local function get_radio_signal_info(device, info)
	local ret = device:send_singleline_command('AT+CESQ', "+CESQ:")
	if ret then
		local rssi, ber, rscp, ecno, rsrq, rsrp = string.match(ret, "%+CESQ:%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")

		rssi = tonumber(rssi)
		if rssi and 0 <= rssi and rssi <= 63 then
			info.rssi = rssi - 111
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

		rscp = tonumber(rscp)
		if rscp and 0 <= rscp and rscp <= 96 then
			info.rscp = rscp - 121
		end

		ecno = tonumber(ecno)
		if ecno and 0 <= ecno and ecno <= 49 then
			info.ecno = ecno / 2 - 24.5
		end

		rsrq = tonumber(rsrq)
		if rsrq and 0 <= rsrq and rsrq <= 34 then
			info.rsrq = rsrq / 2 - 20
		end

		rsrp = tonumber(rsrp)
		if rsrp and 0 <= rsrp and rsrp <= 97 then
			info.rsrp = rsrp - 141
		end
	else
		ret = device:send_singleline_command('AT+CSQ', "+CSQ:")
		if ret then
			local rssi, ber = string.match(ret, "+CSQ:%s?(%d+),%s?(%d+)")

			rssi = tonumber(rssi)
			if rssi and 0 <= rssi and rssi <= 31 then
				info.rssi = 2 * rssi - 113
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
	end

	info.radio_interface = network.get_radio_interface(device)
end

function M.get_radio_signal_info(dev_idx)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	if device.state.powermode == "lowpower" then return nil, "Not available" end

	local info = {}
	run_cacheable_action(dev_idx, "get_radio_signal_info", "get_radio_signal_info", nil, info)
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
	info.roaming_state = network.get_roaming_state(device)
	info.ps_state = network.get_ps_state(device)
	info.cs_state = network.get_cs_state(device)
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
	run_cacheable_action(dev_idx, "get_network_info", "get_network_info", nil, info)
	return info
end

function M.get_time_info(dev_idx)
	local info = {}
	run_cacheable_action(dev_idx, "get_time_info", "get_time_info", nil, info)
	return info
end

local function get_session_info(device, info, session_id)
	local cid = session_id+1
	if device.sessions[cid] and device.sessions[cid].proto ~= "ppp" then
		info.session_state = session.get_state(device, session_id)
	end
	local profiles = session.get_profiles(device)
	for _, profile in pairs(profiles) do
		if tonumber(profile.id) == cid then
			info.apn = profile.apn
			break
		end
	end
	return session.get_session_info(device, info, session_id)
end

function M.get_session_info(dev_idx, session_id)
	local info = {
		session_state = "disconnected"
	}
	run_cacheable_action(dev_idx, "get_session_info" .. session_id, "get_session_info", nil, info, session_id)

	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local cid = session_id+1
	if not info.proto and device.sessions[cid] then
		info.proto = device.sessions[cid].proto
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
	info.access_control_list = sim.get_access_control_list(device)

	info.sim_state = sim.get_state(device)

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
	run_cacheable_action(dev_idx, "get_sim_info", "get_sim_info", nil, info)
	return info
end

local function get_pin_info(device, info)
	local sim_state = sim.get_state(device)
	if sim_state == "locked" then info.pin_state = "enabled_not_verified" end
	if sim_state == "blocked" then info.pin_state = "blocked" end
	if sim_state == "ready" then info.pin_state = "enabled_verified" end

	local pin_enabled = sim.get_locking_facility(device, 'SC')
	if pin_enabled ~= nil then
		if pin_enabled == false then info.pin_state = "disabled" end
	end
end

function M.get_pin_info(dev_idx, pin_type)
	local info = {
		pin_state = "unknown"
	}
	run_cacheable_action(dev_idx, "get_pin_info", "get_pin_info", nil, info, pin_type)

	if tonumber(info.unlock_retries_left) == 0 and tonumber(info.unblock_retries_left) == 0 then
		info.pin_state = "permanently_blocked"
	end
	return info
end

function M.unlock_pin(dev_idx, pin_type, pin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	return sim.unlock(device, pin_type, pin)
end

function M.unblock_pin(dev_idx, pin_type, puk, newpin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	return sim.unblock(device, pin_type, puk, newpin)
end

function M.enable_pin(dev_idx, pin_type, pin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	return sim.enable_pin(device, pin_type, pin)
end

function M.disable_pin(dev_idx, pin_type, pin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	return sim.disable_pin(device, pin_type, pin)
end

function M.change_pin(dev_idx, pin_type, pin, newpin)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	return sim.change_pin(device, pin_type, pin, newpin)
end

function M.start_data_session(dev_idx, session_id, profile)
	return run_action(dev_idx, "start_data_session", session_id, profile)
end

function M.stop_data_session(dev_idx, session_id)
	return run_action(dev_idx, "stop_data_session", session_id)
end

local function configure_device(device, config)
	-- Enable CS network registration events
	if not device:send_command("AT+CREG=2") then
		-- Some handsets in tethered mode don't support CREG=2
		device:send_command("AT+CREG=1")
	end

	-- Enable PS network registration events
	if not device:send_command("AT+CGREG=2") then
		-- Some handsets in tethered mode don't support CGREG=2
		device:send_command("AT+CGREG=1")
	end

	local cops_command = "AT+COPS=0,,"
	if config.network then
		if config.network.selection_pref == "manual" and config.network.mcc and config.network.mnc then
			cops_command = 'AT+COPS=1,2,"' .. config.network.mcc .. config.network.mnc .. '"'
		end

		-- Take the highest priority radio
		local radio = config.network.radio_pref[1]

		if radio.type == "lte" then
			cops_command = cops_command .. ',7'
		elseif radio.type == "umts" then
			cops_command = cops_command .. ',2'
		elseif radio.type == "gsm" then
			cops_command = cops_command .. ',0'
		end

		device:send_command(cops_command, (60*1000))
	end
	return true
end

function M.configure_device(dev_idx, config)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end
	device.buffer.network_info = {}
	device.buffer.voice_info = {messages_waiting = 0}
	device.buffer.radio_signal_info = {}
	local ret = run_action(dev_idx, "configure_device", config)
	device:send_event("mobiled", { event = "device_configured", dev_idx = device.id })
	return ret
end

local function network_scan(device, start)
	if start then
		device.scanresults = {
			scanning = true
		}

		-- This field is for internal use
		device.current_scan = {
			start_time = os.time(),
			tries_left = 2
		}

		local ret = device:start_singleline_command('AT+COPS=?', '+COPS:', (5*60*1000))
		if not ret then
			device.scanresults.scanning = false
			device.current_scan = nil

			-- It makes no sense to retry as the start command only fails when another command is already running or when something serious is wrong with the channel
			return device.scanresults
		end
	elseif not device.scanresults then
		return { scanning = false }
	end

	if device.scanresults.scanning then
		-- Check whether the scan has finished. This also makes (a little) sense when start is true as the scan can be finished (or rather has failed) really fast
		local ret = device:poll_singleline_command()
		if ret ~= true then -- Poll returns true if the command is still running
			local duration = os.difftime(os.time(), device.current_scan.start_time)

			if ret then -- Scan succeeded
				local network_scan_list = {}
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
				device.scanresults.network_scan_list = network_scan_list
				device.scanresults.duration = duration
				device.scanresults.scanning = false
				device.current_scan = nil
			else -- Scan failed
				if device.current_scan.tries_left == 0 then -- The scan has failed all tries
					device.scanresults.duration = duration
					device.scanresults.scanning = false
					device.current_scan = nil
				else -- Try scanning again
					device.current_scan.tries_left = device.current_scan.tries_left - 1
					device:start_singleline_command('AT+COPS=?', '+COPS:', (5*60*1000))
				end
			end
		end
	end

	return device.scanresults
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

function M.set_sms_status(dev_idx, message_id, status) --luacheck: no unused args
	return nil, "Not supported"
end

function M.get_sms_info(dev_idx)
	return run_action(dev_idx, "get_sms_info")
end

function M.get_sms_messages(dev_idx)
	return run_action(dev_idx, "get_sms_messages")
end

function M.reconfigure_plugin(config)
	plugin_config = config or {}
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
		device.buffer.voice_info = {messages_waiting = 0}
		device.buffer.radio_signal_info = {}
		if mode == "lowpower" then
			return device:send_command('AT+CFUN=0', 15000)
		end
		return device:send_command('AT+CFUN=4', 15000)
	end
	return device:send_command('AT+CFUN=1', 15000)
end

function M.set_power_mode(dev_idx, mode)
	local device, errMsg = get_device(dev_idx)
	if not device then return nil, errMsg end

	local result
	result, errMsg = run_action(dev_idx, "set_power_mode", mode)
	if result then
		device.state.powermode = mode
	end
	return result, errMsg
end

local function periodic(device)
	device:get_unsolicited_messages()
	return true
end

function M.periodic(dev_idx)
	return run_action(dev_idx, "periodic")
end

local function set_attach_params(device, profile)
	local pdptype, errMsg = session.get_pdp_type(device, profile.pdptype)
	if not pdptype then
		return nil, errMsg
	end
	local apn = profile.apn or ""
	return device:send_command(string.format('AT+CGDCONT=1,"%s","%s"', pdptype, apn))
end

function M.set_attach_params(dev_idx, profile)
	return run_action(dev_idx, "set_attach_params", profile)
end

local function string_starts(data, pattern)
	return string.sub(data,1,string.len(pattern))==pattern
end

local function execute_command(device, command)
	if device:is_busy() then
		return nil, "Device busy"
	end

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

function M.multi_call(dev_idx, call_id, action, second_call_id)
	return run_action(dev_idx, "multi_call", call_id, action, second_call_id)
end

function M.supplementary_service(dev_idx, service, action, forwarding_type, forwarding_number)
	return run_action(dev_idx, "supplementary_service", service, action, forwarding_type, forwarding_number)
end

function M.send_dtmf(dev_idx, tones, interval, duration)
	return run_action(dev_idx, "send_dtmf", tones, interval, duration)
end

function M.convert_to_data_call(dev_idx, call_id, codec)
	return run_action(dev_idx, "convert_to_data_call", call_id, codec)
end

function M.get_network_interface(dev_idx, session_id)
	local ret = run_action(dev_idx, "get_network_interface", session_id)
	if type(ret) == "string" then
		return ret
	end
end

local function network_attach(device)
	if device.attach_pending then
		return true
	end

	if not device:start_command('AT+CGATT=1', 150000) then
		return false
	end

	device.attach_pending = true
	return true
end

function M.network_attach(dev_idx)
	return run_action(dev_idx, "network_attach")
end

local function network_detach(device)
	return device:send_command('AT+CGATT=0', 150000)
end

function M.network_detach(dev_idx, mode)
	return run_action(dev_idx, "network_detach", mode)
end

local function get_errors(device, errors)
	helper.merge_tables(errors, device.errors)
end

function M.get_errors(dev_idx)
	local errors = {}
	run_action(dev_idx, "get_errors", errors)
	return errors
end

local function flush_errors(device)
	device.errors = {}
	return true
end

function M.flush_errors(dev_idx)
	return run_action(dev_idx, "flush_errors")
end

function M.add_data_session(dev_idx, session_config)
	return run_action(dev_idx, "add_data_session", session_config)
end

local function get_voice_info(device, info)
	info.messages_waiting = device.buffer.voice_info.messages_waiting
end

function M.get_voice_info(dev_idx)
	local info = {}
	run_action(dev_idx, "get_voice_info", info)
	return info
end


function M.get_voice_network_capabilities(dev_idx)
	local info = {}
	run_action(dev_idx, "get_voice_network_capabilities", info)
	return info
end

function M.set_emergency_numbers(dev_idx, numbers)
	return run_action(dev_idx, "set_emergency_numbers", numbers)
end

local function handle_event(device, message)
	if message.event == "command_finished" then
		if message.command == "AT+CGATT=1" then
			device:poll_command()
			device.attach_pending = false
		end
	elseif message.event == "command_cleared" then
		if message.command == "AT+CGATT=1" then
			device.attach_pending = false
		end
	end
end

M.mappings = {
	set_attach_params = set_attach_params,
	network_attach = network_attach,
	network_detach = network_detach,
	get_device_info = get_device_info,
	get_device_capabilities = get_device_capabilities,
	get_radio_signal_info = get_radio_signal_info,
	get_network_info = get_network_info,
	get_session_info = get_session_info,
	get_sim_info = get_sim_info,
	get_pin_info = get_pin_info,
	start_data_session = session.start,
	stop_data_session = session.stop,
	destroy_device = destroy_device,
	configure_device = configure_device,
	set_power_mode = set_power_mode,
	network_scan = network_scan,
	execute_command = execute_command,
	get_profile_info = get_profile_info,
	get_sms_messages = sms.get_messages,
	delete_sms = sms.delete,
	get_sms_info = sms.info,
	send_sms = sms.send,
	accept_call = voice.accept_call,
	dial = voice.dial,
	end_call = voice.end_call,
	call_info = voice.call_info,
	send_dtmf = voice.send_dtmf,
	get_errors = get_errors,
	flush_errors = flush_errors,
	debug = debug,
	handle_event = handle_event,
	periodic = periodic,
	get_ip_info = session.get_ip_info,
	get_voice_info = get_voice_info,
	get_voice_network_capabilities = voice.network_capabilities
}

return M
