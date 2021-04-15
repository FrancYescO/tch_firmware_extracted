local session_helper = require("libat.session")
local network = require("libat.network")
local attty = require("libat.tty")

local Mapper = {}
Mapper.__index = Mapper

local M = {}

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
	local cid = session_id + 1
	local session = device.sessions[cid]
	if not session or session.proto == "ppp" then
		return true
	end

	if session.proto == "dhcp" then
		local apn = profile.apn or ""
		if not session.context_created then
			local pdptype, errMsg = session_helper.get_pdp_type(device, profile.pdptype)
			if not pdptype then
				return nil, errMsg
			end
			if device:send_command(string.format('AT+CGDCONT=%d,"%s","%s"', cid, pdptype, apn)) then
				session.context_created = true
			end
		end

		local host_interface = device.host_interfaces[session_id]
		if host_interface and host_interface.interface then
			if host_interface.interface.desc:match("^rgmii/%d+$") then
				session.is_rgmii = true
				return device:send_command('AT+QETH="SPEED","1000M"') and device:send_command('AT+QETH="RGMII","ENABLE"')
			else
				local status = device.runtime.ubus:call("network.interface", "dump", {})
				if type(status) == "table" and type(status.interface) == "table" then
					for _, interface in pairs(status.interface) do
						if interface.device == host_interface.interface.name and (interface.proto == "dhcp" or interface.proto == "dhcpv6") then
							-- A DHCP interface needs to be created before we can start the data call
							-- When no DHCP client is running, this will return an error
							local pdp_type = translate_pdp_type(profile.pdptype)
							session.pdp_type = pdp_type
							session.is_rgmii = false
							return device:send_multiline_command(string.format("AT$QCRMCALL=1,1,%s,2,%d", pdp_type, cid), "$QCRMCALL:", 300000)
						end
					end
				end
			end
		end
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
		if session.is_rgmii then
			return device:send_command('AT+QETH="RGMII","DISABLE"')
		else
			if session.pdp_type then
				return device:send_command(string.format("AT$QCRMCALL=0,%d,%s", cid, session.pdp_type), 30000)
			end
			return device:send_command(string.format("AT$QCRMCALL=0,%d,%s", cid, "3"), 30000)
		end
	end
end

function Mapper:get_session_info(device, info, session_id)
	local cid = session_id + 1
	local session = device.sessions[cid]
	if not session then
		return true
	end

	-- Workaround for Quectel bug in session state after network deregisters
	local nas_state = network.get_state(device)
	if nas_state ~= "registered" then
		info.session_state = "disconnected"
		info.apn = nil
		return
	end

	if session.proto == "dhcp" then
		info.session_state = "disconnected"
		if session.is_rgmii then
			for _, line in pairs(device:send_multiline_command('AT+CGACT?', '+CGACT:') or {}) do
				local context_id, active = line:match('^%+CGACT:%s*(%d+)%s*,%s*([01])%s*$')
				if tonumber(context_id) == cid then
					if active ~= "1" then
						break
					end
					local address_info = device:send_singleline_command(string.format('AT+CGPADDR=%d', cid), '+CGPADDR:')
					if not address_info then
						break
					end
					local addresses = address_info:match('^%+CGPADDR:%s*%d+%s*,%s*"(.*)"$')
					if not addresses then
						break
					end
					for address in addresses:gmatch('[^,]+') do
						if address:match('^%d+%.%d+%.%d+%.%d+$') then
							info.session_state = "connected"
							info.ipv4 = true
						elseif address:match('^%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+%.%d+$') then
							info.session_state = "connected"
							info.ipv6 = true
						end
					end
					break
				end
			end
		else
			local ipv4_state, ipv6_state
			for _, line in pairs(device:send_multiline_command('AT$QCRMCALL?', "$QCRMCALL:", 5000) or {}) do
				ipv4_state, ipv6_state = line:match("^$QCRMCALL:%s?(%d),V4$QCRMCALL:%s?(%d),V6$")
				if ipv4_state then
					break
				end
				local state, ip_type = line:match('$QCRMCALL:%s?(%d),(V%d)')
				if ip_type == "V4" then
					ipv4_state = state
				end
				if ip_type == "V6" then
					ipv6_state = state
				end
			end
			if ipv4_state == '1' then
				info.session_state = "connected"
				info.ipv4 = true
			end
			if ipv6_state == '1' then
				info.session_state = "connected"
				info.ipv6 = true
			end
		end
	end
end

function Mapper:get_device_capabilities(device, info)
	info.band_selection_support = ""
	info.cs_voice_support = true
	info.volte_support = true
	info.max_data_sessions = 8
	info.supported_auth_types = "none"

	local radio_interfaces = {}
	table.insert(radio_interfaces, { radio_interface = "auto" })
	table.insert(radio_interfaces, { radio_interface = "gsm" })
	table.insert(radio_interfaces, { radio_interface = "umts" })
	table.insert(radio_interfaces, { radio_interface = "lte" })
	info.radio_interfaces = radio_interfaces
end

function Mapper:init_device(device)
	-- Enable NITZ events
	device:send_command('AT+CTZR=2')
	-- Enable packet domain events
	device:send_command('AT+CGEREP=2,1')

	if device.network_interfaces then
		for _, interface in pairs(device.network_interfaces) do
			os.execute(string.format("[ -f /sys/class/net/%s/qmi/raw_ip ] && echo Y > /sys/class/net/%s/qmi/raw_ip", interface.name, interface.name))
		end
	end

	return true
end

function Mapper:configure_device(device, config)
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

	return true
end

-- AT+CFUN=0 will disable the SIM on Quectel modules causing mobiled not to be
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

function Mapper:set_attach_params(device, profile)
	return true
end

function Mapper:network_attach(device)
	-- The module should auto-attach.
	return false
end

function Mapper:network_detach(device)
	return true
end

function Mapper:unsolicited(device, data, sms_data) --luacheck: no unused args
	local prefix, message = data:match('^(%p[%u%s]+):%s*(.*)$')
	if prefix == "+CGEV" and message:match('NW DETACH') then
		device.runtime.log:warning("Received network detach indication")
		return true
	elseif prefix == "+ESM ERROR" or prefix == "+EMM ERROR" then
		local cid, reject_cause = message:match("^(%d+),(%d+)$")
		if cid then
			device:send_event("mobiled", {
				event = "session_disconnected",
				dev_idx = device.dev_idx,
				reject_cause = tonumber(reject_cause),
				session_id = tonumber(cid) - 1
			})
		end
		return true
	end
end

function Mapper:get_network_interface(device, session_id)
	local session = device.sessions[session_id + 1]
	if session then
		return session.interface
	end
end

function Mapper:add_data_session(device, session)
	local cid = session.session_id + 1
	if not device.sessions[cid] then
		device.sessions[cid] = session
		if not session.internal and not session.proto then
			local host_interface = device.host_interfaces[session.session_id]
			if host_interface then
				session.proto = host_interface.proto
				session.interface = host_interface.interface and host_interface.interface.name
				device.runtime.log:error("Using %s for session %d", session.proto, session.session_id)
			else
				device.runtime.log:error("No more host interfaces available")
			end
		elseif session.internal then
			session.proto = "none"
		end
	end
	return true
end

function Mapper:dial(device, number)
	if device:send_singleline_command("AT+QAUDLOOP?", "+QAUDLOOP:") == "+QAUDLOOP: 1" then
		return nil, "Call ongoing"
	end
	if not device:send_command("AT+QAUDLOOP=1") then
		return nil, "Dialing failed"
	end
	return {call_id = 1}
end

function Mapper:end_call(device, call_id)
	if device:send_singleline_command("AT+QAUDLOOP?", "+QAUDLOOP:") == "+QAUDLOOP: 0" then
		return nil, "No call ongoing"
	end
	if not device:send_command("AT+QAUDLOOP=0") then
		return nil, "Failed to end call"
	end
	return true
end

function Mapper:accept_call(device, call_id)
	return nil, "Not supported"
end

function Mapper:send_dtmf(device, tones, interval, duration)
	return nil, "Not supported"
end

function Mapper:multi_call(device, call_id, action, second_call_id)
	return nil, "Not supported"
end

function Mapper:convert_to_data_call(device, call_id, codec)
	return nil, "Not supported"
end

function Mapper:get_voice_network_capabilities(device, info)
	info.cs = {
		emergency = false
	}
	info.volte = {
		emergency = false
	}
	return true
end

function Mapper:get_voice_info(device, info)
	info.emergency_numbers = {}
	info.volte = {
		registration_status = true
	}
end

function Mapper:set_emergency_numbers(device, numbers)
	-- Not supported
end

function M.create(runtime, device) --luacheck: no unused args
	local mapper = {
		mappings = {
			get_session_info = "augment",
			start_data_session = "override",
			stop_data_session = "override",
			configure_device = "override",
			network_attach = "override",
			network_detach = "override",
			set_power_mode = "override",
			dial = "override",
			end_call = "override",
			accept_call = "override",
			send_dtmf = "override",
			multi_call = "override",
			convert_to_data_call = "override",
			get_voice_network_capabilities = "override",
			get_voice_info = "override"
		}
	}

	-- Sessions will be filled dynamically
	device.sessions = {}

	device.default_interface_type = "control"

	device.host_interfaces = {
		[1] = {proto = "none"}, -- Reserved: IMS
		[2] = {proto = "none"}  -- Reserved: emergency
	}

	local non_rgmii_interfaces = {}
	for _, network_interface in ipairs(device.network_interfaces) do
		local rgmii_session = tonumber(network_interface.desc:match("^rgmii/(%d+)$"))
		if rgmii_session then
			device.host_interfaces[rgmii_session] = {proto = "dhcp", interface = network_interface}
		else
			table.insert(non_rgmii_interfaces, network_interface)
		end
	end

	-- Assign the non-RGMII interfaces to the remaining available session IDs.
	local available_session_id = 0
	for _, network_interface in ipairs(non_rgmii_interfaces) do
		while true do
			local session_id = available_session_id
			available_session_id = available_session_id + 1

			if not device.host_interfaces[session_id] then
				device.host_interfaces[session_id] = {proto = "dhcp", interface = network_interface}
				break
			end
		end
	end

	-- Assign the PPP ports to the remaining available session IDs.
	local modem_ports = attty.find_tty_interfaces(device.desc, { number = 0x3 })
	for _, modem_port in ipairs(modem_ports or {}) do
		table.insert(device.interfaces, {port = modem_port, type = "modem"})

		while true do
			local session_id = available_session_id
			available_session_id = available_session_id + 1

			if not device.host_interfaces[session_id] then
				device.host_interfaces[session_id] = {proto = "ppp"}
				break
			end
		end
	end

	local control_ports = attty.find_tty_interfaces(device.desc, { number = 0x02 })
	if control_ports then
		table.insert(device.interfaces, { port = control_ports[1], type = "control" })
	end

	setmetatable(mapper, Mapper)
	return mapper
end

return M
