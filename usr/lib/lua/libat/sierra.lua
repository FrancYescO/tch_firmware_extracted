local string, pairs, table = string, pairs, table
local helper = require("mobiled.scripthelpers")
local session = require("libat.session")
local attty = require("libat.tty")

local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:get_device_info(device, info)
	local ret = device:send_multiline_command('AT!REL?', "")
	if ret then
		for _, line in pairs(ret) do
			if string.match(line, "Protocol:") then
				info["3gpp_release"] = string.match(line, "Protocol:%s+Release%s+(%d+)")
			end
		end
	end
end

function Mapper:get_device_capabilities(device, info)
	local bands = device:send_multiline_command('AT!BAND=?', "")
	if bands then
		local lte_bands = {}
		for _, band in pairs(bands) do
			local id = string.match(band, "(%d+),%s+LTE 1800%s+$")
			if id then
				lte_bands[3] = id
			end
		end
		device.buffer.lte_bands = lte_bands
	end

	local radio_interfaces = {}
	local ret = device:send_multiline_command('AT!SELRAT=?', "")
	if ret then
		for _, line in pairs(ret) do
			if string.match(line, "Automatic") then
				table.insert(radio_interfaces, { radio_interface = "auto" })
			elseif string.match(line, "LTE Only") then
				local supported_bands = {}
				for band in pairs(device.buffer.lte_bands) do
					table.insert(supported_bands, band)
				end
				table.insert(radio_interfaces, { supported_bands = supported_bands, radio_interface = "lte" })
			elseif string.match(line, "UMTS 3G Only") then
				table.insert(radio_interfaces, { radio_interface = "umts" })
				-- Sierra 320U does not actually support GSM but reports it
			elseif string.match(line, "GSM 2G Only") and device.pid ~= "68aa" then
				table.insert(radio_interfaces, { radio_interface = "gsm" })
			end
		end
	end

	info.radio_interfaces = radio_interfaces

	if device.pid == "68aa" then
		info.supported_pdp_types = "ipv4"
	end
end

function Mapper:register_network(device, network_config)
	local selected_radio = {
		priority = 10,
		type = "auto"
	}
	for _, radio in pairs(network_config.radio_pref) do
		if radio.priority < selected_radio.priority then
			selected_radio = radio
		end
	end

	local mode = "00"
	if selected_radio.type == "lte" then
		mode = "06"
	elseif selected_radio.type == "umts" then
		mode = "01"
	elseif selected_radio.type == "gsm" then
		mode = "02"
	end

	local roaming = 1
	if network_config.roaming == false then
		roaming = 0
	end
	device:send_command(string.format('AT^SYSCONFIG=16,3,%d,4', roaming))
	device:send_command(string.format('AT!SELRAT=%s', mode))
	device:send_command('AT+CGATT=1', 15000)
end

function Mapper:create_default_context(device, profile)
	local session_id = 0
	local apn = profile.apn or ""

	local pdptype = session.get_pdp_type(device, profile.pdptype) or "IP"
	--[[
		Using Sierra 320U with PDP type ipv4v6 can cause invalid link state indications in the Sierra directip driver.
		This cause the network link to never become active preventing the DHCP client from fetching the IP.
	]]--
	if device.pid == "68aa" then
		pdptype = "IP"
	end
	local command = string.format('AT+CGDCONT=%d,"%s","%s"', (session_id+1), pdptype, apn)
	device:send_command(command)

	if profile.authentication and profile.password and profile.username then
		local auth_type = "2" -- default  CHAP
		if profile.authentication == "pap" then
			auth_type = "1"
		end
		command = string.format('AT$QCPDPP=%d,%s,"%s","%s"', (session_id+1), auth_type, profile.password, profile.username)
		device:send_command(command)
	else
		device:send_command(string.format('AT$QCPDPP=%d,0', (session_id+1)))
	end

	device:send_command(string.format('AT!SCDFTPROF=%d', (session_id+1)))

	-- Disable default profile
	device:send_command(string.format('AT!SCPROF=%d," ",0,0,0,0', (session_id+1)))
end

function Mapper:start_data_session(device, session_id, profile)
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	device:send_command(string.format('AT!SCACT=1,%d', (session_id + 1)), 30000)
end

function Mapper:stop_data_session(device, session_id)
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	device:send_command(string.format('AT!SCACT=0,%d', (session_id + 1)), 15000)
	helper.sleep(2)
end

function Mapper:get_pin_info(device, info, type)
	local ret = device:send_singleline_command('AT+CPINC?', "+CPINC:", 3000)
	if ret then
		local pin1_unlock_retries, pin2_unlock_retries, pin1_unblock_retries, pin2_unblock_retries = string.match(ret, "+CPINC:%s*(%d+),(%d+),(%d+),(%d+)")
		if type == "pin1" then
			info.unlock_retries_left = pin1_unlock_retries
			info.unblock_retries_left = pin1_unblock_retries
		elseif type == "pin2" then
			info.unlock_retries_left = pin2_unlock_retries
			info.unblock_retries_left = pin2_unblock_retries
		end
	end
end

function Mapper:get_session_info(device, info, session_id)
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	local ret = device:send_multiline_command('AT!SCACT?', '!SCACT:')
	if ret then
		for _, line in pairs(ret) do
			local state, cid = string.match(line, "!SCACT:%s*(%d+),(%d+)")
			if tonumber(cid) == (session_id + 1) then
				if state == "1" then
					info.session_state = "connected"
				end
			end
		end
	end
end

function Mapper:get_sim_info(device, info, session_id)
	local ret = device:send_singleline_command('AT!ICCID?', '!ICCID:')
	if ret then
		local iccid = string.match(ret, '!ICCID:%s?(.+)')
		if iccid then
			if tonumber(string.sub(iccid, 20, 20)) then
				iccid = string.sub(iccid, 1, 20)
			else
				iccid = string.sub(iccid, 1, 19)
			end
			if string.match(string.sub(iccid, 1, 2), "98") then
				iccid = helper.swap(iccid)
			end
			if helper.isnumeric(iccid) then
				device.buffer.sim_info.iccid = iccid
			end
		end
	end
end

local function at_gstatus(device, radio_signal_info, network_info)
	local ret = device:send_multiline_command('AT!GSTATUS?', "")
	if ret then
		local match
		for _, line in pairs(ret) do
			match = string.match(line, "RSRQ%s+%(dB%):%s+([%d-]+)")
			if match then radio_signal_info.rsrq = match end
			match = string.match(line, "RSRP%s+%(dBm%):%s+([%d-]+)")
			if match then radio_signal_info.rsrp = match end
			match = string.match(line, "SINR%s+%(dB%):%s+([%d-%.]+)")
			if match then radio_signal_info.snr = match end
			match = string.match(line, "LTE band:%s+B(%d+)")
			if match then radio_signal_info.lte_band = match end
			match = string.match(line, "LTE bw:%s+(%d+)")
			if match then radio_signal_info.lte_dl_bandwidth = match end
			match = string.match(line, "LTE Rx chan:%s+(%d+)")
			if match then radio_signal_info.dl_earfcn = match end
			match = string.match(line, "LTE Tx chan:%s+(%d+)")
			if match then radio_signal_info.ul_earfcn = match end
			match = string.match(line, "TAC:%s+(%d+)")
			if match then network_info.tracking_area_code = match end
		end
		return true
	end
end

function Mapper:get_radio_signal_info(device, info)
	local ret = device:send_multiline_command('AT+ECIO?', "")
	if ret then
		for _, line in pairs(ret) do
			local ecio = tonumber(string.match(line, 'Ec/Io:%s?([%d%.-]+)'))
			if ecio then
				info.ecio = ecio
			end
		end
	end
	return at_gstatus(device, info, {})
end

function Mapper:network_scan(device, start)
	if start then
		device:send_command('AT+CGATT=0', 15000)
	end
end

function Mapper:get_network_info(device, info)
	at_gstatus(device, {}, info)
	local ret = device:send_singleline_command('AT^SYSINFO', "^SYSINFO:")
	if ret then
		local srv_status, srv_domain, roaming_state = string.match(ret, "%^SYSINFO:%s?(%d),(%d),(%d)")
		if srv_domain == "1" or srv_domain == "3" then
			info.cs_state = "attached"
		end
		if srv_domain == "2" or srv_domain == "3" then
			info.ps_state = "attached"
		end
		if roaming_state == "0" then
			info.roaming_state = "home"
		else
			info.roaming_state = "roaming"
		end
		if srv_status == "0" then
			info.service_state = "no_service"
		elseif srv_status == "1" then
			info.service_state = "limited_service"
		elseif srv_status == "2" then
			info.service_state = "normal_service"
		elseif srv_status == "3" then
			info.service_state = "limited_regional_service"
		elseif srv_status == "4" then
			info.service_state = "sleeping"
		end
	end
end

function Mapper:debug(device)
	table.insert(device.debug.device_state, 'AT!BAND=?')
	local ret = device:send_multiline_command('AT!BAND=?', '')
	if ret then
		for _, line in pairs(ret) do
			table.insert(device.debug.device_state, line)
		end
	end
	table.insert(device.debug.device_state, 'AT!BAND?')
	ret = device:send_multiline_command('AT!BAND?', '')
	if ret then
		for _, line in pairs(ret) do
			table.insert(device.debug.device_state, line)
		end
	end
end

function M.create(runtime, device)
	local mapper = {
		mappings = {
			get_session_info = "override",
			start_data_session = "override",
			stop_data_session = "override",
			register_network = "runfirst",
			network_scan = "runfirst",
			create_default_context = "override"
		}
	}

	device.default_interface_type = "control"

	local ports = attty.find_tty_interfaces(device.desc, { number = 0x3 })
	if ports then
		for _, port in pairs(ports) do
			table.insert(device.interfaces, { port = port, type = "control" })
		end
	end

	setmetatable(mapper, Mapper)
	return mapper
end

return M
