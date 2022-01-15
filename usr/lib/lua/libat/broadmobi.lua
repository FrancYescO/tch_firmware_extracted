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

local Mapper = {}
Mapper.__index = Mapper

function Mapper:configure_device(device, config)
	return true
end

function Mapper:get_device_info(device, info) --luacheck: no unused args
	if not device.buffer.device_info.mode then
		device.buffer.device_info.mode = device:get_mode()
	end
	local result = device:send_singleline_command("AT+BMSWVER", "+BMSWVER:")
	if result then
		local modem_version, efs_version, cdrom_version, apps_version = result:match("^%+BMSWVER: ([^,]*),([^,]*),([^,]*),([^,]*)$")
		if modem_version then
			device.buffer.device_info.software_version = modem_version
		end
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
	end
end

local M = {}

function M.create(runtime, device)
	local mapper = {
		mappings = {
			set_attach_params = "override",
			start_data_session = "override",
			stop_data_session = "override",
			get_session_info = "augment"
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
