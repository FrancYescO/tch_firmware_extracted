local string, tonumber, table, pairs = string, tonumber, table, pairs
local helper = require("mobiled.scripthelpers")
local bit = require("bit")

local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:start_data_session(device, session_id, profile)
	device:send_command("AT^DSFLOWRPT=1")
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	local apn = profile.apn or ""
	return device:send_command('AT^NDISDUP=' .. (session_id + 1) .. ',1,"' .. apn .. '"')
end

function Mapper:stop_data_session(device, session_id)
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	return device:send_command(string.format('AT^NDISDUP=%d,0', (session_id + 1)))
end

local function parse_dsflowrpt(device, data)
	local connection_duration, ul_speed, dl_speed, bytes_sent, bytes_received, max_ul_speed, max_dl_speed = string.match(data, '%^DSFLOWRPT:%s?(%x+),(%x+),(%x+),(%x+),(%x+),(%x+),(%x+)')
	device.buffer.session_info = {
		packet_counters = {
			tx_success = tonumber(bytes_sent, 16),
			rx_success = tonumber(bytes_received, 16)
		},
		duration = tonumber(connection_duration, 16)
	}
	device.buffer.network_info = {
		connection_rate = {
			current_ul_speed = tonumber(ul_speed, 16),
			current_dl_speed = tonumber(dl_speed, 16),
			max_ul_speed = tonumber(max_ul_speed, 16),
			max_dl_speed = tonumber(max_dl_speed, 16)
		}
	}
end

local function parse_ndisstat(device, data)
	local state = tonumber(string.match(data, '%^NDISSTAT:%s*(%d+)'))
	if state == 0 then
		device:send_event("mobiled", { event = "session_disconnected", session_id = 1, dev_idx = device.dev_idx })
	elseif state == 1 then
		device:send_event("mobiled", { event = "session_connected", session_id = 1, dev_idx = device.dev_idx })
	end
end

local function parse_ltersrp(device, data)
	local rsrp, rsrq = string.match(data, '%^LTERSRP:%s*([%d-]+),([%d-]+)')
	device.buffer.radio_signal_info.rsrp = tonumber(rsrp)
	device.buffer.radio_signal_info.rsrq = tonumber(rsrq)
end

local function radio_type_supported(radios, radio_type)
	if type(radios) == "table" then
		for _, radio in pairs(radios) do
			if radio.radio_interface == radio_type then
				return true
			end
		end
	end
	return nil
end

function Mapper:get_sim_info(device, info)
	if not device.buffer.sim_info.iccid then
		local ret = device:send_singleline_command('AT^ICCID?', "^ICCID:", 100)
		if ret then
			local iccid = string.match(ret, '%^ICCID:%s?(.+)')
			if iccid then
				iccid = string.sub(iccid, 1, 19)
				if helper.luhn_checksum(iccid) then
					device.buffer.sim_info.iccid = iccid
				end
			end
		end
	end
end

function Mapper:get_radio_signal_info(device, info)
	helper.merge_tables(info, device.buffer.radio_signal_info)

	local ret = device:send_singleline_command('AT^HCSQ?', "^HCSQ:", 100)
	if ret then
		local type = string.match(ret, '%^HCSQ:*"([A-Z]+)"')

		local rssi = tonumber(string.match(ret, '%^HCSQ:*"[A-Z]+",(%d+)'))
		if(rssi and rssi > 0 and rssi <= 95) then
			info.rssi = (rssi-120)
		end

		if type == "LTE" then
			info.radio_interface = "lte"
			local rsrp, snr, rsrq = string.match(ret, '%^HCSQ:%s?"[A-Z]+",%d+,(%d+),(%d+),(%d+)')
			rsrp = tonumber(rsrp)
			if(rsrp and rsrp > 0 and rsrp <= 97) then
				info.rsrp = (rsrp-140)
			end
			snr = tonumber(snr)
			if(snr and snr > 0 and snr <= 251) then
				info.snr = ((snr*0.2)-20)
			end
			rsrq = tonumber(rsrq)
			if(rsrq and rsrq > 0 and rsrq <= 97) then
				info.rsrq = ((rsrq*0.5)-19.5)
			end
		elseif type == "WCDMA" then
			info.radio_interface = "umts"
			local rscp, ecio = string.match(ret, '%^HCSQ:%s?"[A-Z]+",%d+,(%d+),(%d+)')
			rscp = tonumber(rscp)
			if(rscp and rscp > 0) then
				info.rscp = ((rscp*0.5)-120)
			end
			ecio = tonumber(ecio)
			if(ecio and ecio > 0) then
				info.ecio = ((ecio*0.5)-32)
			end
		end
	end
end

function Mapper:get_pin_info(device, info)
	local ret = device:send_singleline_command('AT^CPIN?', "^CPIN:")
	if ret then
		info.unblock_retries_left, info.unlock_retries_left = string.match(ret, '%^CPIN:.*,%d?,(%d+),(%d+),%d+,%d+')
	end
end

function Mapper:get_ip_info(device, info, session_id)
	local ret = device:send_singleline_command(string.format('AT^DHCPV6=%d', (session_id + 1)), "^DHCPV6:")
	if ret then
		local dns1, dns2 = string.match(ret, "%^DHCPV6:%s*.-,.-,.-,.-,(.-),(.-),")
		if dns1 ~= "::" then info.ipv6_dns1 = dns1 end
		if dns2 ~= "::" then info.ipv6_dns2 = dns2 end
	end
end

function Mapper:get_session_info(device, info, session_id)
	info.packet_counters = device.buffer.session_info.packet_counters
	info.duration = device.buffer.session_info.duration
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	local ret = device:send_singleline_command(string.format('AT^NDISSTATQRY=%d', (session_id + 1)), "^NDISSTATQRY:", 2000)
	if ret then
		local stat = string.match(ret, '%^NDISSTATQRY:%s*%d,(%d),,,"(.-)"')
		if not stat then
			stat = string.match(ret, '%^NDISSTATQRY:%s*(%d),,,"(.-)"')
		end
		if stat == "1" then
			info.session_state = "connected"
		end
	end
end

function Mapper:get_device_capabilities(device, info)
	local radio_interfaces = {}

	local ret = device:send_singleline_command('AT^SYSCFGEX=?', "^SYSCFGEX:")
	if ret then
		local i = 0
		for section in string.gmatch(ret, '%(([A-Z0-9a-z ",/_]-)%)') do
			if i == 0 then
				for word in string.gmatch(section, '([^,]+)') do
					local mode = string.match(word, '"(%d+)"')
					if mode == "00" then
						table.insert(radio_interfaces, { radio_interface = "auto" })
					elseif mode == "01" then
						table.insert(radio_interfaces, { radio_interface = "gsm" })
					elseif mode == "02" then
						table.insert(radio_interfaces, { radio_interface = "umts" })
					elseif mode == "03" then
						table.insert(radio_interfaces, { radio_interface = "lte" })
					elseif mode == "04" or mode == "05" or mode == "07" then
						table.insert(radio_interfaces, { radio_interface = "cdma" })
					end
				end
			elseif (radio_type_supported(radio_interfaces, "gsm") and i == 4) or (not radio_type_supported(radio_interfaces, "gsm") and i == 3) then
				local bands = {}
				for word in string.gmatch(section, 'LTE BC(%d+)') do
					table.insert(bands, word)
				end
				for word in string.gmatch(section, 'LTE_B(%d+)') do
					table.insert(bands, word)
				end
				for word in string.gmatch(section, 'LTE(%d+)') do
					table.insert(bands, word)
				end
				for _, interface in pairs(radio_interfaces) do
					if interface.radio_interface == "lte" then
						interface.supported_bands = bands
					end
				end
			end
			i = i + 1
		end
	end
	info.band_selection_support = "lte"
	info.radio_interfaces = radio_interfaces
end

function Mapper:get_network_info(device, info)
	helper.merge_tables(info, device.buffer.network_info)
end

function Mapper:get_device_info(device, info)
	if not device.buffer.device_info.hardware_version then
		local ret = device:send_singleline_command('AT^HWVER', "^HWVER:")
		if ret then device.buffer.device_info.hardware_version = string.match(ret, '%^HWVER:%s?"(.-)"') end
	end
	info.hardware_version = device.buffer.device_info.hardware_version
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
	local mask
	if selected_radio.type == "lte" then
		mode = "03"
		if selected_radio.bands then
			mask = 0
			for _, band in pairs(selected_radio.bands) do
				mask = bit.bor(mask, bit.lshift(1, band-1))
			end
		end
	elseif selected_radio.type == "umts" then
		mode = "02"
	elseif selected_radio.type == "gsm" then
		mode = "01"
	end

	local roaming = 1
	if network_config.roaming == false then
		roaming = 0
	end

	if mask then
		device:send_command(string.format('AT^SYSCFGEX="%s",3fffffff,%d,4,%x,,', mode, roaming, mask), 100, 2)
	else
		device:send_command(string.format('AT^SYSCFGEX="%s",3fffffff,%d,4,7fffffffffffffff,,', mode, roaming), 100, 2)
	end
end

function Mapper:unsolicited(device, data, sms_data)
	if helper.startswith(data, "^HCSQ:") then
		return true
	elseif helper.startswith(data, "^RSSI:") then
		return true
	elseif helper.startswith(data, "^DSFLOWRPT:") then
		parse_dsflowrpt(device, data)
		return true
	elseif helper.startswith(data, "^NDISSTAT:") or helper.startswith(data, "^NDISSTATEX:") then
		parse_ndisstat(device, data)
		return true
	elseif helper.startswith(data, "^LTERSRP:") then
		parse_ltersrp(device, data)
		return true
	-- Some dongles like the E8372 change their CFUN mode when you unlock the SIM
	elseif helper.startswith(data, "^SIMST:") then
		if device.state.powermode == "lowpower" then
			device:send_command('AT+CFUN=0')
		end
	end
	return nil
end

function Mapper:debug(device)
	local ret = device:send_singleline_command('AT^SYSCFGEX?', '^SYSCFGEX:')
	if ret then table.insert(device.debug.device_state, ret) end
	ret = device:send_singleline_command('AT+CFUN?', '+CFUN:')
	if ret then table.insert(device.debug.device_state, ret) end
	ret = device:send_singleline_command('AT^SYSCFGEX=?', '^SYSCFGEX:')
	if ret then table.insert(device.debug.device_state, ret) end
	ret = device:send_singleline_command('AT^DIALMODE?', '^DIALMODE:')
	if ret then table.insert(device.debug.device_state, ret) end
	ret = device:send_singleline_command('AT^SYSINFO', '^SYSINFO:')
	if ret then table.insert(device.debug.device_state, ret) end
	ret = device:send_singleline_command('AT^SYSINFOEX', '^SYSINFOEX:')
	if ret then table.insert(device.debug.device_state, ret) end
	ret = device:send_singleline_command('AT^DHCP?', '^DHCP:')
	if ret then table.insert(device.debug.device_state, ret) end
	ret = device:send_singleline_command('AT^CPULOAD?', '^CPULOAD:')
	if ret then table.insert(device.debug.device_state, ret) end
	ret = device:send_multiline_command('AT^NDISSTATQRY?', '^NDISSTATQRY:')
	if ret then
		for _, line in pairs(ret) do
			table.insert(device.debug.device_state, line)
		end
	end
	return true
end

function Mapper:init_device(device, network_config)
	device:send_command("AT^CURC=1")
	device:send_command("AT^SIMST=1")
	return true
end

function Mapper:firmware_upgrade(device, path)
	device:send_command('AT^FOTACFG="' .. path .. '","","",0')
	device:send_command("AT^FOTAMODE=0,0,0,1")
	device:send_command("AT^FOTADET")
	return true
end

function Mapper:get_firmware_upgrade_info(device, path)
	device:send_singleline_command('AT^FOTASTATE?', '^FOTASTATE:')
	return nil
end

function Mapper:network_scan(device, start)
	if start then
		device:send_command("AT+CFUN=0")
		helper.sleep(2)
		device:send_command("AT+CFUN=1")
	end
	return true
end

function M.create(pid)
	local mapper = {
		mappings = {
			stop_data_session = "runfirst",
			register_network = "runfirst",
			start_data_session = "override",
			stop_data_session = "override",
			firmware_upgrade = "override",
			get_firmware_upgrade_info = "override",
			network_scan = "runfirst"
		}
	}

	setmetatable(mapper, Mapper)
	return mapper
end

return M
