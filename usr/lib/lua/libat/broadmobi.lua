local at_session = require("libat.session")
local at_network = require("libat.network")
local at_tty = require("libat.tty")

local qcrmcall_pdp_types = {
	["ipv4"]   = 1,
	["ipv6"]   = 2,
	["ipv4v6"] = 3
}
local default_qcrmcall_pdp_type = 3

local qcpdpp_auth_types = {
	["pap"]     = 1,
	["chap"]    = 2,
	["papchap"] = 3
}
local default_qcpdpp_auth_type = 3

local function send_and_parse_command(device, command, prefix, pattern, ...)
	local result = device:send_singleline_command(command, prefix)
	if not result then
		return ...
	end
	return result:sub(prefix:len() + 1):match(pattern)
end

local Mapper = {}
Mapper.__index = Mapper

function Mapper:configure_device(device, config)
	return true
end

function Mapper:get_radio_signal_info(device, info)
	local upper_cell_id, lower_cell_id, phy_cell_id, lte_mode = send_and_parse_command(device, "AT+BMCELLINFO", "+BMCELLINFO:", "^%s*(%d+)%-(%d+),(%d+),([01])$")
	if upper_cell_id then
		info.cell_id = tonumber(upper_cell_id) * 256 + tonumber(lower_cell_id)
		info.phy_cell_id = tonumber(phy_cell_id)

		if lte_mode == "0" then
			info.radio_bearer_type = "FDD LTE"
		elseif lte_mode == "1" then
			info.radio_bearer_type = "TDD LTE"
		end
	end

	local lte_band = send_and_parse_command(device, "AT+BMBAND", "+BMBAND:", "^%s*(%d+)$")
	if lte_band then
		info.lte_band = tonumber(lte_band)
	end

	local radio_interface = send_and_parse_command(device, "AT+BMRAT", "+BMRAT:", "^%s*(.-)%s*$")
	if radio_interface == "TDD LTE" or radio_interface == "FDD LTE" then
		info.radio_interface = "lte"
	elseif radio_interface == "UMTS" then
		info.radio_interface = "umts"
	elseif radio_interface == "GSM" or radio_interface == "GPRS" or radio_interface == "EDGE" then
		info.radio_interface = "gsm"
	end

	-- The values returned by this command often seem wrong or incomplete.
	-- Therefore they are only used if a value was not retrieved using
	-- another command.
	for _, line in pairs(device:send_multiline_command("AT+BMTCELLINFO", "") or {}) do
		for entry in line:gsub("^%+BMTCELLINFO:", ""):gmatch("[^,]+") do
			local key, value = entry:match("^%s*(.-)%s*:%s*(.-)%s*$")
			if key then
				-- Sanitise the key by only keeping letters and digits as the module seems to be
				-- inconsistent about the inclusion of underscores and spaces in the key names.
				key = key:gsub("[^%w]", ""):lower()

				if key == "cellid" then
					if not info.cell_id then
						local cell_id = tonumber(value)
						if cell_id ~= 0 then
							info.cell_id = cell_id
						end
					end
				elseif key == "pci" then
					if not info.phy_cell_id then
						local phy_cell_id = tonumber(value)
						if phy_cell_id ~= 0 then
							info.phy_cell_id = phy_cell_id
						end
					end
				elseif key == "lacid" then
					-- Ignore
				elseif key == "rssi" then
					if not info.rssi then
						info.rssi = tonumber(value)
					end
				elseif key == "rsrp" then
					if not info.rsrp then
						info.rsrp = tonumber(value)
					end
				elseif key == "rsrq" then
					if not info.rsrq then
						info.rsrq = tonumber(value)
					end
				elseif key == "sinr" then
					if not info.sinr then
						info.sinr = tonumber(value)
					end
				elseif key == "activeband" or key == "actvieband" then
					if not info.lte_band then
						local lte_band = tonumber(value)
						if lte_band ~= 0 then
							info.lte_band = lte_band
						end
					end
				elseif key == "activechannel" then
					-- Ignore
				elseif key == "earfcndl" or key == "earfcn" then
					if not info.dl_earfcn then
						local dl_earfcn = tonumber(value)
						if dl_earfcn ~= 0 and dl_earfcn ~= 65535 then
							info.dl_earfcn = dl_earfcn
						end
					end
				elseif key == "earfcnul" then
					if not info.ul_earfcn then
						local ul_earfcn = tonumber(value)
						if ul_earfcn ~= 0 and ul_earfcn ~= 65535 then
							info.ul_earfcn = ul_earfcn
						end
					end
				elseif key == "enodebid" then
					-- Ignore
				elseif key == "tac" then
					-- Ignore
				elseif key == "rrcstatus" then
					-- Ignore
				end
			end
		end
	end
end

function Mapper:get_pin_info(device, info, requested_type)
	local result = send_and_parse_command(device, "AT+BMCPNCNT", "+BMCPNCNT:", "^%s*(.-)%s*$", "")
	for name, parsed_type, retries_left in result:gmatch("(%u+)(%d+)%s*=%s*(%d+)") do
		if requested_type == "pin" .. parsed_type then
			if name == "PIN" then
				info.unlock_retries_left = tonumber(retries_left)
			elseif name == "PUK" then
				info.unblock_retries_left = tonumber(retries_left)
			end
		end
	end
end

function Mapper:get_device_capabilities(device, info)
	info.supported_auth_types = "none pap chap papchap"

	info.radio_interfaces = {
		{ radio_interface = "auto" },
		{ radio_interface = "gsm" },
		{ radio_interface = "umts" },
		{ radio_interface = "lte" }
	}
end

function Mapper:get_device_info(device, info) --luacheck: no unused args
	-- Some dongles do not return the commercial manufacturer name and model.
	if device.vid == "2001" then
		info.manufacturer = "D-Link"
		if device.pid == "7e35" or device.pid == "7e3d" then
			info.model = "DWM-222"
		end
	end

	if not device.buffer.device_info.mode then
		device.buffer.device_info.mode = device:get_mode()
	end
	local modem_version, efs_version, cdrom_version, apps_version = send_and_parse_command(device, "AT+BMSWVER", "+BMSWVER:", "^%s*([^,]*),([^,]*),([^,]*),([^,]*)$")
	if modem_version then
		device.buffer.device_info.software_version = modem_version
	end
end

function Mapper:set_attach_params(device, profile)
	local apn = profile.apn or ""
	local pdptype, errMsg = at_session.get_pdp_type(device, profile.pdptype)
	if not pdptype then
		return nil, errMsg
	end
	local auth_command = "AT$QCPDPP=1,0"
	if profile.authentication and profile.authentication ~= "none" and profile.username and profile.password then
		auth_command = string.format(
			"AT$QCPDPP=1,%d,%s,%s",
			qcpdpp_auth_types[profile.authentication] or default_qcpdpp_auth_type,
			profile.password,
			profile.username
		)
	end
	return device:send_command(auth_command) and device:send_command(string.format('AT+CGDCONT=1,"%s","%s"', pdptype, apn))
end

function Mapper:start_data_session(device, session_id, profile)
	local cid = session_id + 1
	local session = device.sessions[cid]
	if not session or session.proto == "ppp" then
		return true
	end

	if session.proto == "dhcp" then
		local apn = profile.apn or ""
		if not session.context_created then
			local pdptype, errMsg = at_session.get_pdp_type(device, profile.pdptype)
			if not pdptype then
				return nil, errMsg
			end

			local auth_command = string.format("AT$QCPDPP=%d,0", cid)
			if profile.authentication and profile.authentication ~= "none" and profile.username and profile.password then
				auth_command = string.format(
					"AT$QCPDPP=%d,%d,%s,%s",
					cid,
					qcpdpp_auth_types[profile.authentication] or default_qcpdpp_auth_type,
					profile.password,
					profile.username
				)
			end

			if device:send_command(auth_command) and device:send_command(string.format('AT+CGDCONT=%d,"%s","%s"', cid, pdptype, apn)) then
				session.context_created = true
			end
		end

		if device.network_interfaces and device.network_interfaces[cid] then
			local status = device.runtime.ubus:call("network.interface", "dump", {})
			if type(status) == "table" and type(status.interface) == "table" then
				for _, interface in pairs(status.interface) do
					if interface.device == device.network_interfaces[cid] and (interface.proto == "dhcp" or interface.proto == "dhcpv6") then
						-- A DHCP interface needs to be created before we can start the data call
						-- When no DHCP client is running, this will return an error
						local pdp_type = qcrmcall_pdp_types[profile.pdptype] or default_qcrmcall_pdp_type
						session.pdp_type = pdp_type
						return device:send_multiline_command(string.format("AT$QCRMCALL=1,1,%d,2,%d", pdp_type, cid), "$QCRMCALL:", 300000)
					end
				end
			end
		end
		device.runtime.log:notice("Not ready to start data session yet")
	end
end

function Mapper:stop_data_session(device, session_id)
	local cid = session_id + 1
	local session = device.sessions[cid]
	if not session or session.proto == "ppp" then
		return true
	end

	session.context_created = nil

	if session.proto == "dhcp" then
		return device:send_command(string.format("AT$QCRMCALL=0,%d,%d", cid, session.pdp_type or default_qcrmcall_pdp_type), 30000)
	end
end

function Mapper:get_session_info(device, info, session_id)
	local cid = session_id + 1
	local session = device.sessions[cid]
	if not session then
		return true
	end

	-- Workaround for Quectel bug in session state after network deregisters
	local nas_state = at_network.get_state(device)
	if nas_state ~= "registered" then
		info.session_state = "disconnected"
		info.apn = nil
		return
	end

	if session.proto == "dhcp" then
		info.session_state = "disconnected"
		for _, line in pairs(device:send_multiline_command("AT$QCRMCALL?", "$QCRMCALL:", 5000) or {}) do
			local state, ip_type = line:match("^$QCRMCALL:%s*(%d)%s*,%s*(V%d)%s*$")
			if state == "1" then
				if ip_type == "V4" then
					info.session_state = "connected"
					info.ipv4 = true
				elseif ip_type == "V6" then
					info.session_state = "connected"
					info.ipv6 = true
				end
			end
		end
		if info.session_state == "connected" then
			local tx_bytes, rx_bytes = send_and_parse_command(device, "AT+BMRMCALLSTAT", "+BMRMCALLSTAT:", "^.*Down:(%d+)Bytes.*Up:(%d+)Bytes.*$")
			if tx_bytes then
				info.packet_counters = {
					tx_bytes = tonumber(tx_bytes),
					rx_bytes = tonumber(rx_bytes)
				}
			end
		end
	end
end

function Mapper:network_scan(device, start)
	-- Doing a network scan will cause the AT channel to be blocked until the dongle
	-- is restarted. In order to avoid this network scan is disabled.
	return { scanning = false }
end

function Mapper:unsolicited(device, data, sms_data)
	return false
end

local M = {}

function M.create(runtime, device)
	local mapper = {
		mappings = {
			configure_device = "runfirst",
			set_attach_params = "override",
			start_data_session = "override",
			stop_data_session = "override",
			network_scan = "override"
		}
	}

	device.default_interface_type = "control"

	device.host_interfaces = {
		eth = {
			{ proto = "dhcp", interface = device.network_interfaces[1] }
		},
		ppp = {
			{ proto = "ppp" }
		}
	}

	local modem_ports = at_tty.find_tty_interfaces(device.desc, { number = 0x2 })
	for _, port in pairs(modem_ports or {}) do
		table.insert(device.interfaces, { port = port, type = "modem" })
	end

	local control_ports = at_tty.find_tty_interfaces(device.desc, { number = 0x1 })
	for _, port in pairs(control_ports or {}) do
		table.insert(device.interfaces, { port = port, type = "control" })
	end

	setmetatable(mapper, Mapper)
	return mapper
end

return M
