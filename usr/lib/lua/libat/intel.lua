local string, tonumber, table, pairs = string, tonumber, table, pairs
local helper = require("mobiled.scripthelpers")
local attty = require("libat.tty")

local bw_table = { 1.4, 3, 5, 10, 15, 20 }

local Mapper = {}
Mapper.__index = Mapper

local M = {}

function Mapper:set_attach_params(device, profile)
	device:send_command(string.format('AT+CGDCONT=1,"IP","%s"', profile.apn or ""))
end

function Mapper:start_data_session(device, session_id, profile)
	device:send_command('AT+CGACT=0,' .. (session_id + 1), 2000)
	helper.sleep(1)
	device:send_command('AT+XDNS=' .. (session_id + 1) .. ',1')
end

function Mapper:stop_data_session(device, session_id)
	session_id = session_id + 1
	device.modulespecific.crossconnected[session_id] = false
end

function Mapper:get_radio_signal_info(device, info)
	local ret = device:send_singleline_command('AT+XCCINFO?', '+XCCINFO:', 100, 3)
	if ret then
		ret = string.gsub(ret, "+XCCINFO:%s*", "")
		local i = 0
		for val in string.gmatch(ret, '[^,]+') do
			if i == 1 then
				if not device.buffer.network_info.plmn_info then device.buffer.network_info.plmn_info = {} end
				device.buffer.network_info.plmn_info.mcc = val
			elseif i == 2 then
				if not device.buffer.network_info.plmn_info then device.buffer.network_info.plmn_info = {} end
				device.buffer.network_info.plmn_info.mnc = val
			elseif i == 4 then
				if val == "1" then
					info.radio_interface = "gsm"
					device.buffer.network_info = {}
					device.buffer.signal_quality = {}
				elseif val == "2" then
					info.radio_interface = "umts"
					device.buffer.network_info = {}
					device.buffer.signal_quality = {}
				elseif val == "3" then
					info.radio_interface = "lte"
				end
			end
			i = i + 1
		end
	end

	helper.merge_tables(info, device.buffer.radio_signal_info)
end

function Mapper:get_pin_info(device, info)
	local ret = device:send_singleline_command('AT+CPINR="SIM PIN"', '+CPINR:')
	if ret then
		info.unlock_retries_left = tonumber(string.match(ret, '(%d+),'))
	end
	ret = device:send_singleline_command('AT+CPINR="SIM PUK"', '+CPINR:')
	if ret then
		info.unblock_retries_left = tonumber(string.match(ret, '(%d+),'))
	end
end

function Mapper:get_device_capabilities(device, info)
	if not device.buffer.device_capabilities.radio_interfaces then
		local radio_interfaces = {}
		local gsmBands = {}
		local umtsBands = {}
		local lteBands = {}

		local ret = device:send_singleline_command('AT+XACT=?', "+XACT:")
		if ret then
			ret = string.gsub(ret, "+XACT: %([0-9-]+%),%([0-9-]+%),%d,", "")
			for val in string.gmatch(ret, "%d+") do
				val = tonumber(val)
				if(val >= 410 and val <= 1900) then
					table.insert(gsmBands, val)
				elseif(val >= 1 and val <= 25) then
					table.insert(umtsBands, val)
				elseif(val >= 101 and val <= 142) then
					table.insert(lteBands, (val-100))
				end
			end
		end

		table.insert(radio_interfaces, { radio_interface = "auto" })
		if #gsmBands > 0 then
			table.insert(radio_interfaces, { radio_interface = "gsm", supported_bands = gsmBands })
		end
		if #umtsBands > 0 then
			table.insert(radio_interfaces, { radio_interface = "umts", supported_bands = umtsBands })
		end
		if #lteBands > 0 then
			table.insert(radio_interfaces, { radio_interface = "lte", supported_bands = lteBands })
		end

		device.buffer.device_capabilities.radio_interfaces = radio_interfaces
	end

	info.radio_interfaces = device.buffer.device_capabilities.radio_interfaces
	info.band_selection_support = "lte umts"
	info.max_data_sessions = 4
end

function Mapper:get_ip_info(device, info, session_id)
	local ret = device:send_multiline_command("AT+CGDCONT?", "+CGDCONT:")
	if ret then
		for _, line in pairs(ret) do
			local cid, ip = string.match(line, '+CGDCONT: (%d+),"[A-Z0-9]+",".-","([0-9.]+)"')
			if tonumber(cid) == (session_id+1) then
				info.ipv4_addr = ip
			end
		end
	end
	ret = device:send_multiline_command('AT+XDNS?', "+XDNS:")
	if ret then
		for _, line in pairs(ret) do
			local cid, dns1, dns2 = string.match(line, '+XDNS: (%d+), ?"([0-9.]+)", ?"([0-9.]+)"')
			if tonumber(cid) == (session_id + 1) then
				info.ipv4_dns1 = dns1
				info.ipv4_dns2 = dns2
			end
		end
	end
end

function Mapper:get_session_info(device, info, session_id)
	session_id = session_id + 1
	info.proto = "static"
	if info.session_state == "connected" then
		if not device.modulespecific.crossconnected[session_id] then
			device:send_command('AT+XDATACHANNEL=1,1,"/USBCDC/0","/USBHS/NCM/0",0,' .. session_id)
			helper.sleep(1)
			device:send_command('AT+CGDATA="M-RAW_IP",' .. session_id)
			device.modulespecific.crossconnected[session_id] = true
			helper.sleep(1)
		end
	else
		device.modulespecific.crossconnected[session_id] = false
	end
end

function Mapper:configure_device(device, config)
	-- TODO Implement the radio preference list
	local selected_radio = config.network.radio_pref[1]

	local mode = 6
	if selected_radio.type == "gsm" then mode = 0
	elseif selected_radio.type == "umts" then mode = 1
	elseif selected_radio.type == "lte" then mode = 2 end

	local bandstr = ""
	if selected_radio.type == "lte" then
		if selected_radio.bands then
			local bands = {}
			for _, band in pairs(selected_radio.bands) do
				table.insert(bands, band+100)
			end
			bandstr = table.concat(bands, ",") 
		end
	elseif selected_radio.type == "umts" then
		if selected_radio.bands then
			bandstr = table.concat(selected_radio.bands, ",") 
		end
	end

	if mode == 6 then
		device:send_command('AT+XACT=6,2,1')
	else
		local command = string.format('AT+XACT=%d,%d,,%s', mode, mode, bandstr)
		device:send_command(command)
	end
	return true
end

function Mapper:get_network_info(device, info)
	local ret = device:send_singleline_command("AT+XLEC?", "+XLEC:", 200)
	if ret then
		local i = 0
		for val in string.gmatch(ret, "%d+") do
			val = tonumber(val)
			if i == 1 then
				if val == 0 or val == 1 then
					device.runtime.log:info("Not using carrier aggregation")
				else
					device.runtime.log:info("Using carrier aggregation")
					device.runtime.log:info(string.format("Connected to %d cell(s)", val))
				end
			elseif i == 2 then
				device.runtime.log:info(string.format("Primary cell using %.1fMHz", bw_table[val]))
			elseif i == 3 then
				device.runtime.log:info(string.format("Secondary cell using %.1fMHz", bw_table[val]))
			end
			i = i + 1
		end
	end

	helper.merge_tables(info, device.buffer.network_info)
end

function Mapper:init_device(device)
	device.modulespecific = {
		crossconnected = {}
	}

	-- Serving Cell Information URC for LTE
	device:send_command("AT+XMETRIC=1,1,2,20,20")
	-- Signal quality reporting
	device:send_command("AT+XCESQ=1")
	-- Enable carrier aggregation reporting
	-- device:send_command("AT+XLEC=1")

	if device.vid == "8087" and device.pid == "0911" then
		-- Reconfigure the device into 3 ACM + 3 NCM
		device:send_command('AT+GTMULTIOS=0')
		device:send_command('AT+GTUSBMODE=0')
		device:send_command("AT+CFUN=15")
	end
	
	return true
end

local function parse_xcesqi(device, data)
	local rssi, ber, rscp, ecio, rsrq, rsrp, snr = string.match(data, "+XCESQI:%s*(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")

	if not device.buffer.radio_signal_info.rssi then
		rssi = tonumber(rssi)
		if rssi then
			if rssi == 0 then
				device.buffer.radio_signal_info.rssi = -110
			elseif rssi ~= 99 then
				device.buffer.radio_signal_info.rssi = (((63-rssi)*-1)-48)
			end
		end
	end

	if not device.buffer.radio_signal_info.ber then
		ber = tonumber(ber)
		if ber then
			if ber == 0 then
				device.buffer.radio_signal_info.ber = 0.14
			elseif ber == 1 then
				device.buffer.radio_signal_info.ber = 0.28
			elseif ber == 2 then
				device.buffer.radio_signal_info.ber = 0.57
			elseif ber == 3 then
				device.buffer.radio_signal_info.ber = 1.13
			elseif ber == 4 then
				device.buffer.radio_signal_info.ber = 2.26
			elseif ber == 5 then
				device.buffer.radio_signal_info.ber = 4.53
			elseif ber == 6 then
				device.buffer.radio_signal_info.ber = 9.05
			elseif ber == 7 then
				device.buffer.radio_signal_info.ber = 18.10
			end
		end
	end

	device.buffer.radio_signal_info.rscp = nil
	rscp = tonumber(rscp)
	if rscp then
		if rscp == 95 or rscp == 96 then
			device.buffer.radio_signal_info.rscp = -25
		elseif rscp ~= 255 then
			device.buffer.radio_signal_info.rscp = (((92-rscp)*-1)-26)
		end
	end

	device.buffer.radio_signal_info.ecio = nil
	ecio = tonumber(ecio)
	if ecio then
		if ecio == 0 then
			device.buffer.radio_signal_info.ecio = -24
		elseif ecio ~= 255 then
			device.buffer.radio_signal_info.ecio = (((49-ecio)*-0.5))
		end
	end

	device.buffer.radio_signal_info.rsrq = nil
	rsrq = tonumber(rsrq)
	if rsrq then
		if rsrq == 0 then
			device.buffer.radio_signal_info.rsrq = -19.5
		elseif rsrq ~= 255 then
			device.buffer.radio_signal_info.rsrq = (((34-rsrq)*-0.5)-3)
		end
	end

	device.buffer.radio_signal_info.rsrp = nil
	rsrp = tonumber(rsrp)
	if rsrp then
		if rsrp == 0 then
			device.buffer.radio_signal_info.rsrp = -140
		elseif rsrp ~= 255 then
			device.buffer.radio_signal_info.rsrp = (((97-rsrp)*-1)-44)
		end
	end

	device.buffer.radio_signal_info.snr = nil
	snr = tonumber(snr)
	if snr then
		if snr == 100 then
			device.buffer.radio_signal_info.snr = -50
		elseif snr ~= 255 and snr < 0 then
			device.buffer.radio_signal_info.snr = (snr*-0.5)
		elseif snr ~= 255 and snr >= 0 then
			device.buffer.radio_signal_info.snr = (snr*0.5)
		end
	end
end

local function parse_xmetric(device, data)
	if string.match(data, "LTE S CELL") then
		local i = 0
		for val in string.gmatch(data, "[0-9-]+") do
			val = tonumber(val)
			if i == 4 and val ~= 0 then device.buffer.network_info.cell_id = val
			elseif i == 5 and val ~= 0xffff then device.buffer.network_info.tracking_area_code = val
			elseif i == 6 and val ~= 0xffff then device.buffer.radio_signal_info.phy_cell_id = val
			elseif i == 9 and val ~= 0xffff then device.buffer.radio_signal_info.dl_earfcn = val
			elseif i == 10 then device.buffer.radio_signal_info.lte_dl_bandwidth = bw_table[val]
			elseif i == 11 then device.buffer.radio_signal_info.lte_ul_bandwidth = bw_table[val]
			elseif i == 12 and val ~= 255 then device.buffer.radio_signal_info.lte_band = val end
			i = i + 1
		end
	end
end

function Mapper:unsolicited(device, data, sms_data)
	if helper.startswith(data, "+XCESQI:") then
		parse_xcesqi(device, data)
		return true
	elseif helper.startswith(data, "+XMETRIC:") then
		parse_xmetric(device, data)
		return true
	end
	return nil
end

function Mapper:set_power_mode(device, mode)
	if mode == "lowpower" then
		device.buffer.session_info = {}
		device.buffer.network_info = {}
		device.buffer.signal_quality = {}
		return device:send_command('AT+CFUN=4')
	end
	return device:send_command('AT+CFUN=1')
end

function M.create(runtime, device)
	local mapper = {
		mappings = {
			configure_device = "runfirst",
			start_data_session = "runfirst",
			set_power_mode = "override"
		}
	}

	local modem_ports = attty.find_tty_interfaces(device.desc, { number = 0x0 })

	device.default_interface_type = "modem"

	if modem_ports then
		for _, port in pairs(modem_ports) do
			table.insert(device.interfaces, { port = port, type = "modem" })
		end
	end

	setmetatable(mapper, Mapper)
	return mapper
end

return M
