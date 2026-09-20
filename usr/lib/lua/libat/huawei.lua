local string, tonumber, table, pairs = string, tonumber, table, pairs
local firmware_upgrade = require("libat.firmware_upgrade")
local helper = require("mobiled.scripthelpers")
local session = require("libat.session")
local attty = require("libat.tty")
local bit = require("bit")

local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:create_default_context(device, profile)
	local pdptype, errMsg = session.get_pdp_type(device, profile.pdptype)
	if not pdptype then
		return nil, errMsg
	end
	local apn = profile.apn or ""
	device:send_command(string.format('AT+CGDCONT=0,"%s",""', pdptype))
	device:send_command(string.format('AT+CGDCONT=1,"%s","%s"', pdptype, apn))
end

function Mapper:start_data_session(device, session_id, profile)
	device:send_command("AT^DSFLOWRPT=1", 2000, 1, true)
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end

	local pdptype, errMsg = session.get_pdp_type(device, profile.pdptype)
	if not pdptype then
		return nil, errMsg
	end

	local apn = profile.apn or ""
	local command = string.format('AT+CGDCONT=%d,"%s","%s"', (session_id + 1), pdptype, apn)
	local ret = device:send_command(command)
	if ret then
		return device:send_command('AT^NDISDUP=' .. (session_id + 1) .. ',1,"' .. apn .. '"', 5000, 1, true)
	end
end

function Mapper:stop_data_session(device, session_id)
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	return device:send_command(string.format('AT^NDISDUP=%d,0', (session_id + 1)), 5000, 1, true)
end

local function parse_dsflowrpt(device, data)
	local connection_duration, ul_speed, dl_speed, bytes_sent, bytes_received, max_ul_speed, max_dl_speed = string.match(data, '%^DSFLOWRPT:%s?(%x+),(%x+),(%x+),(%x+),(%x+),(%x+),(%x+)')
	device.buffer.session_info = {
		packet_counters = {
			tx_bytes = tonumber(bytes_sent, 16),
			rx_bytes = tonumber(bytes_received, 16)
		},
		duration = tonumber(connection_duration, 16)
	}
	if not device.buffer.network_info then
		device.buffer.network_info = {}
	end
	device.buffer.network_info.connection_rate = {
		current_ul_speed = tonumber(ul_speed, 16),
		current_dl_speed = tonumber(dl_speed, 16),
		max_ul_speed = tonumber(max_ul_speed, 16),
		max_dl_speed = tonumber(max_dl_speed, 16)
	}
end

local function parse_ndisstat(device, data)
	local state = tonumber(string.match(data, '%^NDISSTAT:%s*(%d+)'))
	if state == 0 then
		device:send_event("mobiled", { event = "session_disconnected", session_id = 0, dev_idx = device.dev_idx })
	elseif state == 1 then
		device:send_event("mobiled", { event = "session_connected", session_id = 0, dev_idx = device.dev_idx })
	end
end

local function parse_nwname(device, data)
	local longname, shortname = string.match(data, '%^NWNAME:%s*"(.-)","(.-)"')
	if not device.buffer.network_info then
		device.buffer.network_info = {}
	end
	if not device.buffer.network_info.plmn_info then
		device.buffer.network_info.plmn_info = {}
	end
	if longname and longname ~= "" then
		device.buffer.network_info.plmn_info.description = longname
	elseif shortname and shortname ~= "" then
		device.buffer.network_info.plmn_info.description = shortname
	end
end

local function parse_fotastate(device, data, unsolicited)
	local state = tonumber(string.match(data, '%^FOTASTATE:%s*(%d+)'))
	local status
	if state == 10 then
		status = "not_running"
	elseif state == 11 then
		device.buffer.firmware_upgrade_info.target_version = nil
		status = "checking_version"
	elseif state == 12 then
		status = "upgrade_available"
		local version = string.match(data, '%^FOTASTATE:%s*%d+,(.-),')
		if version then
			device.buffer.firmware_upgrade_info.target_version = version
		end
	elseif state == 14 then
		device.buffer.firmware_upgrade_info.target_version = nil
		status = "no_upgrade_available"
	elseif state == 30 then
		status = "downloading"
	elseif state == 40 then
		status = "downloaded"
	elseif state == 50 then
		status = "flashing"
	elseif state == 90 then
		status = "done"
	elseif state == 13 or state == 20 or state == 80 then
		status = "failed"
		device.buffer.firmware_upgrade_info.error_code = tonumber(string.match(data, '%^FOTASTATE:%s*%d+,(%d+)'))
	end

	if device.buffer.firmware_upgrade_info.status ~= "done" and device.buffer.firmware_upgrade_info.status ~= "failed" then
		device.buffer.firmware_upgrade_info.status = status
	end

	if unsolicited then
		-- Because the device will go away in flashing mode, we store the state and target version in /var/state
		firmware_upgrade.update_state(device, device.buffer.firmware_upgrade_info)
		if status == "done" or status == "no_upgrade_available" then
			device:send_event("mobiled", { event = "firmware_upgrade_done", dev_idx = device.dev_idx })
		elseif status == "failed" then
			device:send_event("mobiled", { event = "firmware_upgrade_failed", dev_idx = device.dev_idx })
		end
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
end

function Mapper:get_radio_signal_info(device, info)
	helper.merge_tables(info, device.buffer.radio_signal_info)

	local ret = device:send_singleline_command('AT^HCSQ?', "^HCSQ:", 100)
	if ret then
		local type = string.match(ret, '%^HCSQ:%s?"([A-Z]+)"')

		local rssi = tonumber(string.match(ret, '%^HCSQ:%s?"[A-Z]+",(%d+)'))
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

local function match_ndisstat(data)
	if not data then
		return
	end
	local stat4, stat6 = string.match(data, '%^NDISSTATQRY:%s?(%d),,,"IPV4",(%d)')
	if not stat4 then
		stat4, stat6 = string.match(data, '%^NDISSTATQRY:%s?%d,(%d),,,"IPV4",(%d)')
		if not stat4 then
			-- IPv4 only module?
			stat4 = string.match(data, '%^NDISSTATQRY:%s?(%d),,,"IPV4"')
		end
	end
	return stat4, stat6
end

function Mapper:get_session_info(device, info, session_id)
	info.packet_counters = device.buffer.session_info.packet_counters
	info.duration = device.buffer.session_info.duration
	if device.sessions[session_id + 1].proto == "ppp" then
		return true
	end
	local ret = device:send_singleline_command(string.format('AT^NDISSTATQRY=%d', (session_id + 1)), "^NDISSTATQRY:", 2000, 1, true)
	local stat4, stat6 = match_ndisstat(ret)
	if stat4 == "1" or stat6 == "1" then
		info.session_state = "connected"
	else
		-- Some modules report 0 on the above form of the command so check again
		ret = device:send_multiline_command('AT^NDISSTATQRY?', "^NDISSTATQRY:", 2000, 1, true)
		if ret then
			for _, s in pairs(ret) do
				stat4, stat6 = match_ndisstat(s)
				if stat4 == "1" or stat6 == "1" then
					info.session_state = "connected"
				end
			end
		end
	end
end

function Mapper:get_device_capabilities(device, info)
	local radio_interfaces = {}

	-- Apparently there is no way of retrieving this from the module/dongle
	local voice_support = {
		["K5160"] = { cs_voice_support = true },
		["K4203"] = { cs_voice_support = true }
	}

	if device.buffer.device_info.model then
		local support = voice_support[device.buffer.device_info.model]
		if support then
			if support.cs_voice_support ~= nil then
				info.cs_voice_support = support.cs_voice_support
			end
			if support.volte_support ~= nil then
				info.volte_support = support.volte_support
			end
		end
	end

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
	else
		ret = device:send_singleline_command('AT^SYSCFG=?', "^SYSCFG:")
		if ret then
			local section = string.match(ret, '%(([A-Z0-9a-z ",/_]-)%)')
			for word in string.gmatch(section, '([^,]+)') do
				local mode = string.match(word, '(%d+)')
				if mode == "2" then
					table.insert(radio_interfaces, { radio_interface = "auto" })
				elseif mode == "13" then
					table.insert(radio_interfaces, { radio_interface = "gsm" })
				elseif mode == "14" then
					table.insert(radio_interfaces, { radio_interface = "umts" })
				end
			end
		end
	end
	if radio_type_supported(radio_interfaces, "lte") then
		info.band_selection_support = "lte"
	end
	info.radio_interfaces = radio_interfaces
end

function Mapper:get_network_info(device, info)
	helper.merge_tables(info, device.buffer.network_info)
	local ret = device:send_singleline_command('AT^SYSINFOEX', "^SYSINFOEX:")
	if ret then
		local srv_status, srv_domain, roaming_state = string.match(ret, "%^SYSINFOEX:%s?(%d),(%d),(%d)")
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

local function get_supported_voice_interfaces(device)
	local ret = device:send_singleline_command('AT^DDSETEX=?', "^DDSETEX:")
	if ret then
		ret = string.match(ret, '%^DDSETEX:%s?%((.-)%)$')
		if ret then
			local voice_interfaces = {}
			for port in string.gmatch(ret, '([^,]+)') do
				table.insert(voice_interfaces, tonumber(port))
			end
			return voice_interfaces
		end
	end
	return nil
end

function Mapper:get_device_info(device, info)
	if not device.buffer.device_info.hardware_version then
		local ret = device:send_singleline_command('AT^HWVER', "^HWVER:")
		if ret then device.buffer.device_info.hardware_version = string.match(ret, '%^HWVER:%s?"(.-)"') end
	end
	if not device.buffer.device_info.imeisv then
		local ret = device:send_singleline_command('AT^IMEISV?', "^IMEISV:")
		if ret then device.buffer.device_info.imeisv = string.match(ret, '%^IMEISV:%s?(.-)$') end
	end
	if not device.buffer.device_info.voice_interfaces then
		local ddsetex_interfaces = {
			[2] = {
				name = "diag",
				protocol = 0x3,
				number = 0x1
			}
		}
		local supported_voice_interfaces = get_supported_voice_interfaces(device)
		if supported_voice_interfaces then
			local voice_interfaces = {}
			for _, interface in pairs(supported_voice_interfaces) do
				local huawei_interface = ddsetex_interfaces[interface]
				if huawei_interface then
					local vp = attty.find_tty_interfaces(device.desc, { protocol = huawei_interface.protocol })
					if type(vp) == "table" and #vp >= 1 then
						table.insert(voice_interfaces, { type = "serial", device = vp[1]})
					else
						vp = attty.find_tty_interfaces(device.desc, { number = huawei_interface.number })
						if type(vp) == "table" and #vp >= 1 then
							table.insert(voice_interfaces, { type = "serial", device = vp[1]})
						end
					end
				end
			end
			device.buffer.device_info.voice_interfaces = voice_interfaces
		end
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

local call_ind_states = {
	-- call_originate
	[0] = {
		call_state = "dialing",
		media_state = "normal"
	},
	-- alerting
	[2] = {
		call_state = "delivered",
		media_state = "normal"
	},
	-- connected
	[3] = {
		call_state = "connected",
		media_state = "normal"
	},
	-- released
	[4] = {
		call_state = "no_call",
		media_state = "no_media"
	},
	-- incoming
	[5] = {
		call_state = "alerting",
		media_state = "no_media"
	},
	-- waiting
	[6] = {
		call_state = "alerting",
		media_state = "no_media"
	},
	-- held
	[7] = {
		call_state = "connected",
		media_state = "held"
	},
	-- retrieve
	[8] = {
		call_state = "connected",
		media_state = "normal"
	}
}

function Mapper:unsolicited(device, data, sms_data)
	if helper.startswith(data, "^HCSQ:") then
		return true
	elseif helper.startswith(data, "^STIN:") then
		return true
	elseif helper.startswith(data, "^RSSI:") then
		return true
	elseif helper.startswith(data, "^DSFLOWRPT:") then
		parse_dsflowrpt(device, data)
		return true
	elseif helper.startswith(data, "^FOTASTATE:") then
		parse_fotastate(device, data, true)
		return true
	elseif helper.startswith(data, "^NDISSTAT:") or helper.startswith(data, "^NDISSTATEX:") then
		parse_ndisstat(device, data)
		return true
	elseif helper.startswith(data, "^NWNAME:") then
		parse_nwname(device, data)
		return true
	elseif helper.startswith(data, "^LTERSRP:") then
		parse_ltersrp(device, data)
		return true
	-- Some dongles like the E8372 change their CFUN mode when you unlock the SIM
	elseif helper.startswith(data, "^SIMST:") then
		if device.state.powermode == "lowpower" then
			device:send_command('AT+CFUN=0')
		end
		local sim_state = data:match("%^SIMST:%s?(%d+)")
		if sim_state == "1" then
			device.buffer.sim_info = {}
			device:send_event("mobiled", { event = "sim_initialized", dev_idx = device.dev_idx })
		elseif sim_state == "255" then
			device.buffer.sim_info = {}
			device:send_event("mobiled", { event = "sim_removed", dev_idx = device.dev_idx })
		else
			device.buffer.sim_info = {}
			device:send_event("mobiled", { event = "sim_error", dev_idx = device.dev_idx })
		end
		return true
	elseif helper.startswith(data, "^ORIG:") then
		--local call_id, call_type = data:match("%^ORIG:%s?(%d+),(%d+)")
		return true
	elseif helper.startswith(data, "^CONF:") then
		--local call_id = data:match("%^CONF:%s?(%d+)")
		return true
	elseif helper.startswith(data, "^CONN:") then
		--local call_id, call_type = data:match("%^CONN:%s?(%d+),(%d+)")
		device:send_command("AT^DDSETEX=2")
		return true
	elseif helper.startswith(data, "^CEND:") then
		local call_id, duration = data:match("%^CEND:%s?(%d+),(%d+),%d+,%d+")
		call_id = tonumber(call_id)
		if call_id and device.calls[call_id] then
			device.calls[call_id].duration = duration
		end
		return true
	elseif helper.startswith(data, "^CCALLSTATE:") then
		local call_id, call_status = data:match("%^CCALLSTATE:%s?(%d+),(%d+)")
		call_id = tonumber(call_id)
		call_status = tonumber(call_status)
		if not device.calls[call_id] then
			device.calls[call_id] = {}
		end
		local state = call_ind_states[call_status]
		if state then
			local event = false
			if device.calls[call_id].call_state ~= state.call_state then
				event = true
			end
			device.calls[call_id].call_state = state.call_state
			device.calls[call_id].media_state = state.media_state

			if device.calls[call_id].call_state == "alerting" then
				device.calls[call_id].call_id = call_id
				device.calls[call_id].direction = "incoming"
			end
			if event then
				device:send_event("mobiled", { event = "call_state_changed", call_id = call_id, dev_idx = device.dev_idx, call_state = device.calls[call_id].call_state })
			end
			-- Remove call info when released
			if call_status == 4 then
				device.calls[call_id] = nil
			end
		end
		return true
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
	ret = device:send_singleline_command('AT^FOTACFG?', '^FOTACFG:')
	if ret then table.insert(device.debug.device_state, ret) end
	ret = device:send_singleline_command('AT^FOTASTATE?', '^FOTASTATE:')
	if ret then table.insert(device.debug.device_state, ret) end
	ret = device:send_singleline_command('AT^FOTAMODE?', '^FOTAMODE:')
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
	if not device.state.initialized then
		device:send_command("AT^CURC=1")
		device:send_command("AT^SIMST=1")
		device:send_command("AT+COLP=1")
		device:send_command("AT+CHUP")
		device.buffer.firmware_upgrade_info = { status = "not_running" }
		local info = firmware_upgrade.get_state()
		if info then
			device.buffer.firmware_upgrade_info = info
		end
		firmware_upgrade.reset_state()
	end
	return true
end

function Mapper:firmware_upgrade(device, path)
	if not path then
		device.buffer.firmware_upgrade_info.status = "invalid_parameters"
		return nil, "Invalid parameters"
	end

	local parts = {}
	for part in string.gmatch(path, '([^,]+)') do
		table.insert(parts, part)
	end

	local apn = parts[1]
	local username = parts[2]
	local password = parts[3]
	if not apn then
		device.buffer.firmware_upgrade_info.status = "invalid_parameters"
		return nil, "Invalid parameters"
	end

	device:send_command("AT^FOTADL=0")
	device.buffer.firmware_upgrade_info = { status = "started" }
	firmware_upgrade.reset_state()

	-- In order to pass past FOTA state 40, any data session should be terminated
	device:send_command(string.format('AT^NDISDUP=%d,0', 1), 5000)

	device:send_command(string.format('AT^FOTACFG="%s",%s,%s,0', apn, username or "", password or ""))
	device:send_command("AT^FOTAMODE=0,1,1,1")
	device:send_command("AT^FOTADET")
	return true
end

function Mapper:get_firmware_upgrade_info(device, path)
	if device.buffer.firmware_upgrade_info.status ~= "invalid_parameters" then
		local ret = device:send_singleline_command('AT^FOTASTATE?', '^FOTASTATE:')
		if ret then parse_fotastate(device, ret, false) end
	end
	return device.buffer.firmware_upgrade_info
end

function Mapper:network_scan(device, start)
	if start then
		helper.sleep(5)
		device:send_command("AT+CFUN=0")
		helper.sleep(2)
		device:send_command("AT+CFUN=1")
	end
	return true
end

function Mapper:dial(device, number)
	local ret = device:send_command(string.format("ATD%s;", number))
	if ret then
		device.calls[1] = {
			call_id = 1
		}
		return device.calls[1]
	end
	return nil, "Dialing failed"
end

function Mapper:end_call(device, call_id)
	device:send_command("AT+CHUP")
	return true
end

function Mapper:accept_call(device, call_id)
	device:send_command("ATA")
	return true
end

local clcc_number_type = {
	["129"] = "normal",
	["145"] = "international"
}

local clcc_direction = {
	["0"] = "outgoing",
	["1"] = "incoming"
}

function Mapper:call_info(device, call_id)
	call_id = tonumber(call_id)

	local ret = device:send_multiline_command("AT+CLCC", "+CLCC:", 2000)
	if ret then
		for _, call in pairs(ret) do
			local id, direction, _, _, _, remote_party, number_type = string.match(call, '%+CLCC:%s*(%d+),(%d+),(%d+),(%d+),(%d+),"(.-)",(%d+),".-"')
			id = tonumber(id)
			if id then
				if not device.calls[id] then
					device.calls[id] = {}
				end
				device.calls[id].remote_party = remote_party
				device.calls[id].direction = clcc_direction[direction]
				device.calls[id].number_format = clcc_number_type[number_type]
			end
		end
	end

	if call_id and device.calls[call_id] then
		ret = device:send_singleline_command(string.format("AT^CDUR=%d", call_id), "^CDUR:")
		if ret then
			device.calls[call_id].duration = string.match(ret, "%^CDUR:%s?%d+,(%d+)")
		end
	else
		for _, call in pairs(device.calls) do
			if call.call_id then
				ret = device:send_singleline_command(string.format("AT^CDUR=%d", call.call_id), "^CDUR:")
				if ret then
					call.duration = string.match(ret, "%^CDUR:%s?%d+,(%d+)")
				end
			end
		end
	end

	if call_id then
		return device.calls[call_id] or {}
	end
	return device.calls or {}
end

function Mapper:multi_call(device, call_id, action)
	if action == "hold_call" then
		return true
	elseif action == "resume_call" then
		return true
	elseif action == "release_held_call" then
		return true
	elseif action == "conf_call" then
		return true
	elseif action == "accept_call_waiting_release_active_call" then
		return true
	elseif action == "accept_call_waiting_hold_active_call" then
		return true
	elseif action == "reject_call_waiting" then
		return true
	elseif action == "ccbs" then
		return true
	end
	return nil, "Invalid action"
end

function Mapper:supplementary_service(device, service, action, params, forwarding_type, forwarding_number)
	local ret
	if service == "call_waiting" then
		if action == "activate" then
			device:send_command("AT+CCWA=1,1,1")
			return true
		elseif action == "deactivate" then
			device:send_command("AT+CCWA=1,0,1")
			return true
		elseif action == "query" then
			ret = device:send_singleline_command("AT+CCWA=1,2,1", "+CCWA:", 60000)
			if ret then
				local status = string.match(ret, "+CCWA:%s?(%d)")
				if status == "1" then
					return { status = "activated" }
				end
			end
			return { status = "deactivated" }
		end
		return nil, "Invalid action"
	elseif service == "clip" then
		if action == "activate" then
			device:send_command("AT+CLIP=1")
			return true
		elseif action == "deactivate" then
			device:send_command("AT+CLIP=0")
			return true
		elseif action == "query" then
			ret = device:send_singleline_command("AT+CLIP?", "+CLIP:", 60000)
			local info = {
				status = "unknown",
				enabled = false
			}
			if ret then
				local enabled, status = string.match(ret, "+CLIP:%s?(%d),(%d)")
				if enabled == "1" then
					info.enabled = true
				end
				if status == "0" then
					info.status = "unavailable"
				elseif status == "1" then
					info.status = "available"
				end
			end
			return info
		end
		return nil, "Invalid action"
	elseif service == "clir" then
		if action == "activate" then
			device:send_command("AT+CLIR=1")
			return true
		elseif action == "deactivate" then
			device:send_command("AT+CLIR=0")
			return true
		elseif action == "query" then
			ret = device:send_singleline_command("AT+CLIR?", "+CLIR:", 60000)
			local info = {
				status = "unknown",
				enabled = false
			}
			if ret then
				local enabled, status = string.match(ret, "+CLIR:%s?(%d),(%d)")
				if enabled == "1" then
					info.enabled = true
				end
				if status == "0" then
					info.status = "unavailable"
				elseif status == "1" then
					info.status = "available"
				elseif status == "3" then
					info.status = "temporarily_unavailable"
				elseif status == "4" then
					info.status = "temporarily_available"
				end
			end
			return info
		end
		return nil, "Invalid action"
	elseif service == "colp" then
		if action == "activate" then
			device:send_command("AT+COLP=1")
			return true
		elseif action == "deactivate" then
			device:send_command("AT+COLP=0")
			return true
		elseif action == "query" then
			ret = device:send_singleline_command("AT+COLP?", "+COLP:", 60000)
			local info = {
				status = "unknown",
				enabled = false
			}
			if ret then
				local enabled, status = string.match(ret, "+COLP:%s?(%d),(%d)")
				if enabled == "1" then
					info.enabled = true
				end
				if status == "0" then
					info.status = "unavailable"
				elseif status == "1" then
					info.status = "available"
				end
			end
			return info
		end
		return nil, "Invalid action"
	elseif service == "call_forwarding" then
		local forwarding_translation = {
			["unconditional"] = 0,
			["busy"] = 1,
			["no_reply"] = 2,
			["unreachable"] = 3,
			["all_types"] = 4,
			["all_conditional_types"] = 5
		}

		if action == "activate" then
			local number_type = "129"
			if params.forwarding_number_type == "international" then
				number_type = "145"
			end
			device:send_command(string.format('AT+CCFC=%d,1,"%s",%d', forwarding_translation[params.forwarding_type], params.forwarding_number, number_type))
			return true
		elseif action == "deactivate" then
			device:send_command("AT+CCFC=0")
			return true
		elseif action == "query" then
			ret = device:send_singleline_command(string.format("AT+CCFC=%d,2", forwarding_translation[params.forwarding_type]), "+CCFC:", 60000)
			local info = {
				enabled = false
			}
			if ret then
				local enabled = string.match(ret, '+CCFC:%s?(%d)')
				if enabled == "1" then
					info.enabled = true
				end
			end
			return info
		end
		return nil, "Invalid action"
	end
	return nil, "Invalid service"
end

function M.create(pid)
	local mapper = {
		mappings = {
			register_network = "runfirst",
			start_data_session = "override",
			stop_data_session = "override",
			firmware_upgrade = "override",
			get_firmware_upgrade_info = "override",
			network_scan = "runfirst",
			supplementary_service = "override",
			multi_call = "override",
			call_info = "override",
			dial = "override"
		}
	}

	setmetatable(mapper, Mapper)
	return mapper
end

return M
