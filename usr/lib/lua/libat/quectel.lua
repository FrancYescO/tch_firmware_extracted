local string, tonumber = string, tonumber

local attty = require("libat.tty")

local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:get_pin_info(device, info, type)
	local ret = device:send_multiline_command('AT+QPINC?', "+QPINC:", 3000)
	if ret then
		for _, line in pairs(ret) do
			local pin_type, pin_unlock_retries, pin_unblock_retries = string.match(line, '+QPINC:%s?"(.-)",%s?(%d+),%s?(%d+)')
			if (type == "pin1" and pin_type == "SC") or (type == "pin2" and pin_type == "P2") then
				info.unlock_retries_left = pin_unlock_retries
				info.unblock_retries_left = pin_unblock_retries
			end
		end
	end
end

local function translate_pdp_type(pdp_type)
	if pdp_type == "ipv4" then
		return "1"
	elseif pdp_type == "ipv6" then
		return "2"
	else
		return "3"
	end
end

function Mapper:start_data_session(device, session_id, profile)
	local id = session_id + 1
	if device.network_interfaces and device.network_interfaces[id] then
		local status = device.runtime.ubus:call("network.interface", "dump", {})
		if type(status) == "table" and type(status.interface) == "table" then
			for _, interface in pairs(status.interface) do
				if interface.device == device.network_interfaces[id] and (interface.proto == "dhcp" or interface.proto == "dhcpv6") then
					-- A DHCP interface needs to be created before we can start the data call
					-- When no DHCP client is running, this will return an error
					local pdp_type = translate_pdp_type(profile.pdp_type)
					device.sessions[id].pdp_type = pdp_type
					device:send_multiline_command(string.format("AT$QCRMCALL=1,%d,%s,2", id, pdp_type), "$QCRMCALL:", 300000)
				end
			end
		end
	end
end

function Mapper:stop_data_session(device, session_id)
	local id = session_id + 1
	if device.sessions[id].pdp_type then
		return device:send_command(string.format("AT$QCRMCALL=0,%d,%s", id, device.sessions[session_id + 1].pdp_type), 30000)
	else
		return device:send_command(string.format("AT$QCRMCALL=0,%d,%s", id, "3"), 30000)
	end
end

function Mapper:get_session_info(device, info, session_id)
	info.dhcp = { use_l3_ifname = true }
	local ret = device:send_multiline_command('AT$QCRMCALL?', "$QCRMCALL:", 5000)
	if ret then
		for _, line in pairs(ret) do
			local state = string.match(line, '$QCRMCALL:%s?(%d)')
			if state == '1' then
				info.session_state = "connected"
			end
		end
	end
end

function Mapper:get_network_info(device, info)
	local ret = device:send_singleline_command('"AT+QENG="servingcell"', "+QENG:")
	if ret then
		local act = string.match(ret, '+QENG:%s?"servingcell",".-","(.-)"')
		local mcc, mnc, cell_id
		if act == 'LTE' then
			local tracking_area_code
			mcc, mnc, cell_id, tracking_area_code = string.match(ret, '+QENG:%s?"servingcell",".-","LTE",".-",(%d+),(%d+),(%x+),%d+,%d+,%d+,%d+,%d+,(%x+),[%d-]+,[%d-]+,[%d-]+,[%d-]+')
			if tracking_area_code then
				info.tracking_area_code = tonumber(tracking_area_code, 16)
			end
		elseif act == "GSM" or act == "WCDMA" then
			local location_area_code
			mcc, mnc, location_area_code, cell_id = string.match(ret, '+QENG:%s?"servingcell",".-",".-",(%d+),(%d+),(%x+),(%x+)')
			if location_area_code then
				info.location_area_code = tonumber(location_area_code, 16)
			end
		end
		if mcc and mnc then
			if not info.plmn_info then info.plmn_info = {} end
			info.plmn_info.mcc = mcc
			info.plmn_info.mnc = mnc
		end
		if cell_id then
			info.cell_id = tonumber(cell_id, 16)
		end
	end
end

local function get_bandwidth(bw)
	if bw == '0' then
		return 1.4
	elseif bw == '1' then
		return 3
	elseif bw == '2' then
		return 5
	elseif bw == '3' then
		return 10
	elseif bw == '4' then
		return 15
	elseif bw == '5' then
		return 20
	end
end

function Mapper:get_radio_signal_info(device, info)
	local ret = device:send_singleline_command('AT+QNWINFO', "+QNWINFO:")
	if ret then
		info.radio_bearer_type = string.match(ret, '+QNWINFO:%s?"(.-)"')
	end
	ret = device:send_singleline_command('"AT+QENG="servingcell"', "+QENG:")
	if ret then
		local act = string.match(ret, '+QENG:%s?"servingcell",".-","(.-)"')
		if act == 'LTE' then
			local phy_cell_id, earfcn, band, ul_bw, dl_bw, rsrp, rsrq, rssi, sinr = string.match(ret, '+QENG:%s?"servingcell",".-","LTE",".-",%d+,%d+,%x+,(%d+),(%d+),(%d+),(%d+),(%d+),%x+,([%d-]+),([%d-]+),([%d-]+),([%d-]+)')
			info.lte_band = tonumber(band)
			info.lte_ul_bandwidth = get_bandwidth(ul_bw)
			info.lte_dl_bandwidth = get_bandwidth(dl_bw)
			info.rsrp = tonumber(rsrp)
			info.rsrq = tonumber(rsrq)
			info.rssi = tonumber(rssi)
			sinr = tonumber(sinr)
			if sinr then
				info.sinr = ((sinr/5)-20)
			end
			info.dl_earfcn = tonumber(earfcn)
			info.phy_cell_id = tonumber(phy_cell_id)
		elseif act == 'GSM' then
			local arfcn = string.match(ret, '+QENG:%s?"servingcell",".-","GSM",%d+,%d+,%x+,%x+,%d+,(%d+)')
			info.dl_arfcn = tonumber(arfcn)
		elseif act == 'WCDMA' then
			local uarfcn, rscp, ecio = string.match(ret, '+QENG:%s?"servingcell",".-","WCDMA",%d+,%d+,%x+,%x+,(%d+),%d+,%d+,([%d-]+),([%d-]+)')
			info.dl_uarfcn = tonumber(uarfcn)
			info.rscp = tonumber(rscp)
			info.ecio = tonumber(ecio)
		end
	end
end

function Mapper:get_device_capabilities(device, info)
	local radio_interfaces = {}

	table.insert(radio_interfaces, { radio_interface = "auto" })
	table.insert(radio_interfaces, { radio_interface = "gsm" })
	table.insert(radio_interfaces, { radio_interface = "umts" })
	table.insert(radio_interfaces, { radio_interface = "lte" })

	info.radio_interfaces = radio_interfaces
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

	local mode = "0"
	if selected_radio.type == "lte" then
		mode = "3"
	elseif selected_radio.type == "umts" then
		mode = "2"
	elseif selected_radio.type == "gsm" then
		mode = "1"
	end
	device:send_command(string.format('AT+QCFG="nwscanmode",%d,1', mode))

	local roaming = 2
	if network_config.roaming == false then
		roaming = 1
	end
	device:send_command(string.format('AT+QCFG="roamservice",%d,1', roaming))
end

function M.create(runtime, device)
	local mapper = {
		mappings = {
			get_session_info = "override",
			start_data_session = "override",
			stop_data_session = "override"
		}
	}

	device.default_interface_type = "control"

	local ports = attty.find_tty_interfaces(device.desc, { number = 0x02 })
	if ports then
		table.insert(device.interfaces, { port = ports[1], type = "control" })
	end
	setmetatable(mapper, Mapper)
	return mapper
end

return M