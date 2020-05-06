local atchannel = require("atchannel")
local attty = require("libat.tty")
local bit = require("bit")
local firmware_upgrade = require("libat.firmware_upgrade")
local helper = require("mobiled.scripthelpers")
local network = require("libat.network")

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
					return
				end
			end
		end
	end
	device.runtime.log:info("Not ready to start data session yet")
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
	local ret = device:send_singleline_command('AT+QENG="servingcell"', "+QENG:")
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
	ret = device:send_singleline_command('AT+QENG="servingcell"', "+QENG:")
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

function Mapper:network_scan(device, start)
	if start and device.cops_command then
		-- Deregister from the network before starting the scan, otherwise it will fail.
		device:send_command("AT+COPS=2")
	end
end

local function parse_cgreg_state(data)
    -- +CGREG: <n>, <stat>, <lac>, <cid>, <Act>
    local stat, lac, cid, act = string.match(data, '+CGREG:%s?%d,(%d),"(%x*)","(%x*)",(%d)')
    if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16), tonumber(act) end
    -- +CGREG: <n>, <stat>, <lac>, <cid>
    stat, lac, cid = string.match(data, '+CGREG:%s*%d,(%d),"(%x*)","(%x*)"')
    if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16) end
    -- +CGREG: <stat>, <lac>, <cid>, <radio type>
    stat, lac, cid, act = string.match(data, '+CGREG:%s*(%d),"(%x*)","(%x*)",(%d)')
    if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16), tonumber(act) end
    -- +CGREG: <n>, <stat>, <lac>, <cid>
    stat, lac, cid = string.match(data, '+CGREG:%s*%d,%s?(%d),%s?(%x*),%s?(%x*)')
    if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16) end
    -- +CGREG: <stat>, <lac>, <cid>
    stat, lac, cid = string.match(data, "+CGREG:%s*(%d),%s?(%x*),%s?(%x*)")
    if stat then return tonumber(stat), tonumber(lac, 16), tonumber(cid, 16) end
    -- +CGREG: <n>, <stat>
    stat = string.match(data, "+CGREG:%s*%d,%s?(%d)")
    if stat then return tonumber(stat) end
    -- +CGREG: <stat>
    stat = string.match(data, "+CGREG:%s?(%d)")
    if stat then return tonumber(stat) end

    return nil
end

local function get_network_state(device)
    local ret = device:send_singleline_command("AT+CGREG?", "+CGREG:")
    local state, lac, cid, act
    if ret then
        state, lac, cid, act = parse_cgreg_state(ret)
    end
    -- 0000, and FFFE are reserved to indicate there is no valid LAC
    if lac == 65534 or lac == 0 then
        lac = nil
    end
    return network.creg_state_to_string(state), lac, cid, network.creg_radio_type_to_string(act)
end

function Mapper:get_network_info(device, info)
	local area_code, act
	info.nas_state, area_code, info.cell_id, act = get_network_state(device)
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

function Mapper:configure_device(device, config)
	local sim_hotswap_enabled = false
	local ret = device:send_singleline_command('AT+QSIMDET?', "+QSIMDET:")
	if ret and string.match(ret, '^+QSIMDET:%s?(%d),%d$') == '1' then
		sim_hotswap_enabled = true
	end
	if config.sim_hotswap and not sim_hotswap_enabled then
		-- Enable SIM hotswap events on low level GPIO transition
		device:send_command("AT+QSIMDET=1,0")
		-- Reset the device to apply the change
		device:send_command("AT+CFUN=1,1")
	elseif not config.sim_hotswap and sim_hotswap_enabled then
		-- Platform doesn't support SIM hotswap so disable it
		device:send_command("AT+QSIMDET=0,0")
		-- Reset the device to apply the change
		device:send_command("AT+CFUN=1,1")
	end

	local mode = 0
	local lte_band_mask
	for _, radio in ipairs(config.network.radio_pref) do
		if radio.type == "auto" then
			mode = 63
			break
		elseif radio.type == "lte" then
			lte_band_mask = helper.get_lte_band_mask(radio.bands)
			mode = bit.bor(mode, 16)
		elseif radio.type == "umts" then
			mode = bit.bor(mode, 8, 32)
		elseif radio.type == "gsm" then
			mode = bit.bor(mode, 4)
		elseif radio.type == "cdma2000" then
			mode = bit.bor(mode, 1, 2)
		end
	end
	device:send_command(string.format('AT+QCFG="nwscanmodeex",%d,1', mode))
	if lte_band_mask then
		device:send_command(string.format('AT+QCFG="band",ffff,%x,3f,1', lte_band_mask))
	else
		device:send_command('AT+QCFG="band",ffff,ffffffffff,3f,1')
	end

	-- Enable network registration events
	local ret = device:send_command("AT+CGREG=2")
	if not ret then
		-- Some handsets in tethered mode don't support CGREG=2
		device:send_command("AT+CGREG=1")
	end

	-- Construct the COPS command but do not execute it yet. Executing the COPS
	-- command on Quectel modules before the SIM is unlocked will return OK but
	-- afterwards the CGATT command will fail until COPS=2 and COPS=0 are called
	-- again. This command however requires information from the network config so
	-- it is constructed here and stored for later use.
	if config.network then
		local cops_command = "AT+COPS=0,,"
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

		device.cops_command = cops_command
	end

	local roaming = 2
	if config.network.roaming == "none" then
		roaming = 1
	end
	device:send_command(string.format('AT+QCFG="roamservice",%d,1', roaming))
	return true
end

function Mapper:init_device(device)
	-- Enable NITZ events
	device:send_command("AT+CTZR=2")
	-- Enable packet domain events
	device:send_command("AT+CGEREP=2,1")

	device.buffer.firmware_upgrade_info = { status = "not_running" }
	local info = firmware_upgrade.get_state()
	if info then
		device.buffer.firmware_upgrade_info = info
	end
	firmware_upgrade.reset_state()

	return true
end

function Mapper:destroy_device(device)
	-- Disable CGREG notifications
	return device:send_command("AT+CGREG=0")
end

-- AT+CFUN=0 will disable the SIM om Quectel modules causing mobiled not to be
-- able to initialise the SIM anymore.  Therefore CFUN=4 is used in both the
-- lowpower and airplane power modes.
function Mapper:set_power_mode(device, mode)
	if mode == "lowpower" or mode == "airplane" then
		device.buffer.session_info = {}
		device.buffer.network_info = {}
		device.buffer.radio_signal_info = {}
		return device:send_command('AT+CFUN=4', 5000)
	end
	return device:send_command('AT+CFUN=1', 5000)
end

function Mapper:firmware_upgrade(device, path)
	if not path then
		device.buffer.firmware_upgrade_info.status = "invalid_parameters"
		return nil, "Invalid parameters"
	end

	local current_revision = device:get_revision()
	if not current_revision then
		device.buffer.firmware_upgrade_info.status = "failed"
		return nil, "Unable to determine current revision"
	end

	local url = path:gsub("<REVISION>", current_revision)

	-- Start the upgrade process.
	if not device:send_command(string.format('AT+QFOTADL="%s"', url)) then
		device.buffer.firmware_upgrade_info.status = "failed"
		return nil, "Unable to start firmware upgrade"
	end

	device.buffer.firmware_upgrade_info = { status = "started" }
	firmware_upgrade.reset_state()

	return true
end

local function convert_time(datetime, tz, dst)
	local daylight_saving_time = tonumber(dst)
	local timezone = tonumber(tz) * 15
	local localtime
	local year, month, day, hour, min, sec = string.match(datetime, "(%d+)/(%d+)/(%d+),(%d+):(%d+):(%d+)")
	if year then
		localtime = os.time({day=day,month=month,year=year,hour=hour,min=min,sec=sec})
		return localtime, timezone, daylight_saving_time
	end
end

function Mapper:unsolicited(device, data, sms_data)
	local prefix, message = data:match('^(%p%u+):%s*(.*)$')
	if prefix == "+CTZE" then
		local tz, dst, datetime = message:match('^"([+0-9]+)",(%d),"(.-)"$')
		local localtime, timezone, daylight_saving_time = convert_time(datetime, tz, dst)
		local event_data = {
			event = "time_update_received",
			daylight_saving_time = daylight_saving_time,
			localtime = localtime,
			timezone = timezone,
			dev_idx = device.dev_idx
		}
		device:send_event("mobiled", event_data)
		return true
	elseif prefix == "+QIND" then
		local qind_command, qind_arguments = message:match('^"([^"]+)",?%s*(.*)$')
		if qind_command == "FOTA" then
			local fota_command, fota_arguments = qind_arguments:match('^"(%u+)",?%s*(.*)$')
			if fota_command == "FTPSTART" then
				device.buffer.firmware_upgrade_info.status = "downloading"
			elseif fota_command == "FTPEND" then
				local ftp_error = tonumber(fota_arguments)
				if ftp_error then
					if ftp_error == 0 then
						device.buffer.firmware_upgrade_info.status = "downloaded"
					else
						device.buffer.firmware_upgrade_info.status = "failed"
						device.buffer.firmware_upgrade_info.error_code = ftp_error
						device:send_event("mobiled", { event = "firmware_upgrade_failed", dev_idx = device.dev_idx })
					end
				end
			elseif fota_command == "HTTPSTART" then
				device.buffer.firmware_upgrade_info.status = "downloading"
			elseif fota_command == "HTTPEND" then
				local http_error = tonumber(fota_arguments)
				if http_error then
					if http_error == 0 then
						device.buffer.firmware_upgrade_info.status = "downloaded"
					else
						device.buffer.firmware_upgrade_info.status = "failed"
						device.buffer.firmware_upgrade_info.error_code = http_error
						device:send_event("mobiled", { event = "firmware_upgrade_failed", dev_idx = device.dev_idx })
					end
				end
			elseif fota_command == "START" then
				device.buffer.firmware_upgrade_info.status = "flashing"
			elseif fota_command == "UPDATING" then
				local progress = tonumber(fota_arguments)
				if progress then
					device.buffer.firmware_upgrade_info.status = "flashing"
				end
			elseif fota_command == "END" then
				local error_code = tonumber(fota_arguments)
				if error_code then
					if error_code == 0 then
						device.buffer.firmware_upgrade_info.status = "done"
						device:send_event("mobiled", { event = "firmware_upgrade_done", dev_idx = device.dev_idx })
					else
						device.buffer.firmware_upgrade_info.status = "failed"
						device.buffer.firmware_upgrade_info.error_code = error_code
						device:send_event("mobiled", { event = "firmware_upgrade_failed", dev_idx = device.dev_idx })
					end
				end
			end

			firmware_upgrade.update_state(device, device.buffer.firmware_upgrade_info)
		end
	elseif prefix == "+CREG" then
		return true
	elseif prefix == "+CGREG" then
		local stat = parse_cgreg_state(data)
		local state = network.creg_state_to_string(stat)
		if state then
			device.runtime.log:info("Network registration state changed to: " .. state)
			if state == "registered" then
				device:send_event("mobiled", { event = "network_registered", dev_idx = device.dev_idx })
			elseif state == "not_registered" then
				device:send_event("mobiled", { event = "network_deregistered", dev_idx = device.dev_idx })
			end
		end
		return true
	end
end

function Mapper:get_time_info(device, info)
	local ret = device:send_singleline_command("AT+QLTS=2", "+QLTS:")
	if ret then
		local datetime, tz, dst = string.match(ret, '^+QLTS:%s?"([%d/,:]+)([%+%-%d]+),(%d)"')
		info.localtime, info.timezone, info.daylight_saving_time = convert_time(datetime, tz, dst)
		return true
	end
end

function Mapper:set_attach_params(device, profile)
	-- Deregister from the network before registering from the network because
	-- otherwise setting the attach parameters will not take effect.
	device:send_command('AT+COPS=2', 60000)
end

function Mapper:network_attach(device, info)
	if device.cops_command then
		-- Deregister from the network before registering again, otherwise registering will fail.s
		device:send_command('AT+COPS=2', 60000)
		device:send_command(device.cops_command, 60000)
	end

	return true
end

function M.create(runtime, device)
	local mapper = {
		mappings = {
			get_session_info = "override",
			start_data_session = "override",
			stop_data_session = "override",
			network_scan = "runfirst",
			get_network_info = "override",
			configure_device = "override",
			set_power_mode = "override",
			set_attach_params = "runfirst",
			network_attach = "runfirst"
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
