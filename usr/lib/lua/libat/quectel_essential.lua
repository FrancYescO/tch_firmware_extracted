local script_helpers = require("mobiled.scripthelpers")
local session_helper = require("libat.session")
local network = require("libat.network")
local attty = require("libat.tty")

local CALL_ID = 1

local IPPT_STATE = 1
local RGMII_SPEED = "1000M"

local function translate_pdp_type(pdp_type)
	if pdp_type == "ipv4" then
		return "1"
	elseif pdp_type == "ipv6" then
		return "2"
	else
		return "3"
	end
end

local Mapper = {}
Mapper.__index = Mapper

local function get_rgmii_state(device)
	for _, line in ipairs(device:send_multiline_command('AT+QETH="RGMII"', '+QETH:', 10000)) do
		local rgmii_state, ippt_state = line:match('^%+QETH:%s*"RGMII","(%w+)",1,(%-?[01])$')
		if rgmii_state then
			return rgmii_state == "ENABLE", tonumber(ippt_state)
		end
	end

	-- Return nil to indicate error but also return a valid value for the IPPT state
	-- so that the nil can be interpreted as RGMII not enabled.
	return nil, -1
end

local function normalise_mac_address(mac_address)
	if not mac_address then
		return nil
	end

	local match = mac_address:match("%x%x[-:]%x%x[-:]%x%x[-:]%x%x[-:]%x%x[-:]%x%x")
	if not match then
		return nil
	end

	return match:upper():gsub("-",":")
end

local function enable_rgmii(device, interface_name)
	-- Determine the MAC address of the interface.
	local mac_address = normalise_mac_address(script_helpers.read_file(string.format("/sys/class/net/%s/address", interface_name)))
	if not mac_address then
		device.runtime.log:error("Failed to determine MAC address")
		return false
	end

	local rgmii_enabled, current_ippt_state = get_rgmii_state(device)
	if rgmii_enabled then
		local current_mac_address = device:send_singleline_command('AT+QETH="IPPTMAC"', '+QETH:', 10000)
		if current_mac_address then
			current_mac_address = normalise_mac_address(current_mac_address:match('^%+QETH:%s*"[Ii][Pp][Pp][Tt][Mm][Aa][Cc]",%s*(.*)$'))
		end

		local current_speed = device:send_singleline_command('AT+QETH="SPEED"', '+QETH:', 10000)
		if current_speed then
			current_speed = current_speed:match('^%+QETH:%s*"[Ss][Pp][Ee][Ee][Dd]",%s*"(.*)"$')
		end

		if IPPT_STATE == current_ippt_state and mac_address == current_mac_address and RGMII_SPEED == current_speed then
			device.runtime.log:info("Not enabling RGMII, already enabled")
			return true
		else
			device.runtime.log:info("Disabling RGMII to change parameters: IPPT state from %d to %d, MAC address from %s to %s and speed from %s to %s", current_ippt_state, IPPT_STATE, current_mac_address or "(none)", mac_address, current_speed or "(none)", RGMII_SPEED)
			device:send_command(string.format('AT+QETH="RGMII","DISABLE",1,%d', current_ippt_state), 10000)
		end
	end

	-- Set the IPPT MAC address.
	if IPPT_STATE == 1 and not device:send_command(string.format('AT+QETH="IPPTMAC",%s', mac_address), 10000) then
		device.runtime.log:error("Failed to set IPPT MAC address")
		return false
	end

	-- Set the RGMII speed.
	if not device:send_command(string.format('AT+QETH="SPEED","%s"', RGMII_SPEED), 10000) then
		device.runtime.log:error("Failed to set RGMII speed")
		return false
	end

	-- Enable RGMII.
	if not device:send_command(string.format('AT+QETH="RGMII","ENABLE",1,%d', IPPT_STATE), 10000) then
		device.runtime.log:error("Failed to enable RGMII")
		return false
	end

	device.runtime.log:info("Enabled RGMII")
	return true
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
		if host_interface and host_interface.interface and host_interface.interface.desc then
			if host_interface.interface.desc:match("^rgmii/%d+$") then
				return enable_rgmii(device, host_interface.interface.name)
			else
				local status = device.runtime.ubus:call("network.interface", "dump", {})
				if type(status) == "table" and type(status.interface) == "table" then
					for _, interface in pairs(status.interface) do
						if interface.device == host_interface.interface.name and (interface.proto == "dhcp" or interface.proto == "dhcpv6") then
							-- A DHCP interface needs to be created before we can start the data call
							-- When no DHCP client is running, this will return an error
							local pdp_type = translate_pdp_type(profile.pdptype)
							session.pdp_type = pdp_type
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
		local host_interface = device.host_interfaces[session_id]
		if host_interface and host_interface.interface and host_interface.interface.desc then
			if not host_interface.interface.desc:match("^rgmii/%d+$") then
				if session.pdp_type then
					return device:send_command(string.format("AT$QCRMCALL=0,%d,%s", cid, session.pdp_type), 30000)
				end
				return device:send_command(string.format("AT$QCRMCALL=0,%d,%s", cid, "3"), 30000)
			end
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
		local host_interface = device.host_interfaces[session_id]
		if host_interface and host_interface.interface and host_interface.interface.desc then
			if host_interface.interface.desc:match("^rgmii/%d+$") then
				if session.interface then
					local ipv4_status = device.runtime.ubus:call("network.interface." .. session.interface .. "_4", "status", {})
					if ipv4_status and ipv4_status.up then
						info.session_state = "connected"
						info.ipv4 = true
					end

					local ipv6_status = device.runtime.ubus:call("network.interface." .. session.interface .. "_6", "status", {})
					if ipv6_status and ipv6_status.up then
						info.session_state = "connected"
						info.ipv6 = true
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
end

local bandwidth_map = {
	['0'] = 1.4,
	['1'] = 3,
	['2'] = 5,
	['3'] = 10,
	['4'] = 15,
	['5'] = 20,
	['6'] = 1.4,
	['15'] = 3,
	['25'] = 5,
	['50'] = 10,
	['75'] = 15,
	['100'] = 20
}

function Mapper:get_radio_signal_info(device, info)
	local ret = device:send_singleline_command('AT+QNWINFO', "+QNWINFO:")
	if ret then
		info.radio_bearer_type = ret:match('+QNWINFO:%s?"(.-)"')
	end

	local radio_gsm = false
	local radio_umts = false
	local radio_lte = false
	local radio_nr_nsa = false

	for _, line in ipairs(device:send_multiline_command('AT+QENG="servingcell"', "+QENG:") or {}) do
		-- For LTE, UMTS and GSM the command returns a single line containing both the
		-- connection state and the radio information. For 5G the command returns the
		-- connection state, the LTE radio information and the 5G radio information on
		-- separate lines. Since we are only interested in the radio information we
		-- strip the connection state and process each returned line as radio
		-- information so all information can be treated the same. In care of 5G, the
		-- line containing the connection state will be ignored.
		line = line:gsub('^%+QENG:%s*', ''):gsub('^"servingcell","%u+"', '')

		local act = line:match('"(.-)"')
		if act == 'NR5G-NSA' then
			radio_nr_nsa = true

			local phy_cell_id, rsrp, sinr, rsrq = line:match('"NR5G%-NSA",%d+,%d+,(%d+),(%-?%d+),(%-?%d+),(%-?%d+)')

			phy_cell_id = tonumber(phy_cell_id)
			info.nr_phy_cell_id = phy_cell_id

			rsrp = tonumber(rsrp)
			local measured_rsrp
			if rsrp ~= -32768 then
				measured_rsrp = rsrp
				info.nr_rsrp = measured_rsrp
			end

			rsrq = tonumber(rsrq)
			local measured_rsrq
			if rsrq ~= -32768 then
				measured_rsrq = rsrq
				info.nr_rsrq = measured_rsrq
			end

			sinr = tonumber(sinr)
			local recalculated_sinr
			if sinr and sinr ~= -32768 then
				recalculated_sinr = sinr / 5 - 20
				info.nr_sinr =recalculated_sinr
			end

			info.secondary_cell_group = {
				radio_interface = "nr",
				primary_secondary_cell = {
					phy_cell_id = phy_cell_id,
					rsrp = measured_rsrp,
					rsrq = measured_rsrq,
					sinr = recalculated_sinr
				}
			}
		elseif act == 'LTE' then
			radio_lte = true

			local phy_cell_id, earfcn, band, ul_bw, dl_bw, rsrp, rsrq, rssi, sinr, tx_power = line:match('"LTE",".-",%d+,%d+,%x+,(%d+),(%d+),(%d+),(%d+),(%d+),%x+,([%d-]+),([%d-]+),([%d-]+),([%d-]+),[%d-]+,([%d-]+)')
			if not phy_cell_id then
				phy_cell_id, earfcn, band, ul_bw, dl_bw, rsrp, rsrq, rssi, sinr = line:match('"LTE",".-",%d+,%d+,%x+,(%d+),(%d+),(%d+),(%d+),(%d+),%x+,([%d-]+),([%d-]+),([%d-]+),([%d-]+)')
			end
			info.lte_band = tonumber(band)
			info.lte_ul_bandwidth = bandwidth_map[ul_bw]
			info.lte_dl_bandwidth = bandwidth_map[dl_bw]
			info.rsrp = tonumber(rsrp)
			info.rsrq = tonumber(rsrq)
			info.rssi = tonumber(rssi)
			sinr = tonumber(sinr)
			if sinr then
				info.sinr = sinr * 2 - 20
			end
			tx_power = tonumber(tx_power)
			if tx_power and tx_power ~= -32768 then
				info.tx_power = tx_power/10
			end
			info.dl_earfcn = tonumber(earfcn)
			info.phy_cell_id = tonumber(phy_cell_id)

			info.master_cell_group = {
				radio_interface = "lte",
				primary_cell = {
					lte_band = info.lte_band,
					lte_ul_bandwidth = info.lte_ul_bandwidth,
					lte_dl_bandwidth = info.lte_dl_bandwidth,
					rsrp = info.rsrp,
					rsrq = info.rsrq,
					rssi = info.rssi,
					sinr = info.sinr,
					tx_power = info.tx_power,
					dl_earfcn = info.dl_earfcn,
					phy_cell_id = info.phy_cell_id
				}
			}

			local ca_info = device:send_multiline_command("AT+QCAINFO", "+QCAINFO:")
			if ca_info then
				local secondary_cell_list = {}
				local secondary_cell_map = {}

				local carriers = {}

				for _, line2 in pairs(ca_info) do
					earfcn, dl_bw, band, phy_cell_id, rsrp, rsrq, rssi, sinr = line2:match('^%+QCAINFO:%s*"[Ss][CcSs][CcSs]",(%d+),(%d+),"LTE BAND (%d+)",%d+,(%d+),([%d-]+),([%d-]+),([%d-]+),([%d-]+)')
					if earfcn then
						phy_cell_id = tonumber(phy_cell_id)
						earfcn = tonumber(earfcn)
						band = tonumber(band)
						dl_bw = bandwidth_map[dl_bw]
						rsrp = tonumber(rsrp)
						rsrq = tonumber(rsrq)
						rssi = tonumber(rssi)
						sinr = tonumber(sinr)

						local secondary_cell = secondary_cell_map[phy_cell_id]
						if not secondary_cell then
							secondary_cell = {
								phy_cell_id = phy_cell_id,
								carrier_components = {}
							}
							table.insert(secondary_cell_list, secondary_cell)
							secondary_cell_map[phy_cell_id] = secondary_cell
						end

						table.insert(secondary_cell.carrier_components, {
							dl_earfcn = earfcn,
							lte_band = band,
							lte_dl_bandwidth = dl_bw,
							rsrp = rsrp,
							rsrq = rsrq,
							rssi = rssi,
							sinr = sinr
						})
						info.master_cell_group.secondary_cells = secondary_cell_list

						table.insert(carriers, {
							dl_earfcn = earfcn,
							phy_cell_id = phy_cell_id,
							lte_band = band,
							lte_dl_bandwidth = dl_bw,
							rsrp = rsrp,
							rsrq = rsrq,
							rssi = rssi,
							sinr = sinr
						})
						info.additional_carriers = carriers
					end
				end
			end
		elseif act == 'GSM' then
			radio_gsm = true

			local arfcn = line:match('^"GSM",%d+,%d+,%x+,%x+,%d+,(%d+)')
			info.dl_arfcn = tonumber(arfcn)

			info.master_cell_group = {
				radio_interface = "gsm",
				primary_cell = {
					dl_arfcn = info.dl_arfcn
				}
			}
		elseif act == 'WCDMA' then
			radio_umts = true

			local uarfcn, rscp, ecio = line:match('^"WCDMA",%d+,%d+,%x+,%x+,(%d+),%d+,%d+,([%d-]+),([%d-]+)')
			info.dl_uarfcn = tonumber(uarfcn)
			info.rscp = tonumber(rscp)
			info.ecio = tonumber(ecio)

			info.master_cell_group = {
				radio_interface = "umts",
				primary_cell = {
					dl_uarfcn = info.dl_uarfcn,
					rscp = info.rscp,
					ecio = info.ecio
				}
			}
		end
	end

	if radio_nr_nsa then
		info.radio_interface = "endc"
	elseif radio_lte then
		info.radio_interface = "lte"
	elseif radio_umts then
		info.radio_interface = "umts"
	elseif radio_gsm then
		info.radio_interface = "gsm"
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
		return session.host_interface
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
				session.host_interface = host_interface.interface and host_interface.interface.name
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

	if device.voice_timer then
		device.voice_timer:cancel()
	end
	device.voice_timer = device.runtime.uloop.timer(function()
		device:send_event("mobiled.voice", {
			event = "call_state_changed",
			call_id = CALL_ID,
			dev_idx = device.dev_idx,
			call_state = "dialing"
		})
		device.voice_timer = device.runtime.uloop.timer(function()
			device:send_event("mobiled.voice", {
				event = "call_state_changed",
				call_id = CALL_ID,
				dev_idx = device.dev_idx,
				call_state = "delivered"
			})
			device.voice_timer = device.runtime.uloop.timer(function()
				device:send_event("mobiled.voice", {
					event = "call_state_changed",
					call_id = CALL_ID,
					dev_idx = device.dev_idx,
					call_state = "connected"
				})
				device.voice_timer = nil
			end, 500)
		end, 500)
	end, 500)

	return {call_id = CALL_ID}
end

function Mapper:end_call(device, call_id)
	if device:send_singleline_command("AT+QAUDLOOP?", "+QAUDLOOP:") == "+QAUDLOOP: 0" then
		return nil, "No call ongoing"
	end
	if not device:send_command("AT+QAUDLOOP=0") then
		return nil, "Failed to end call"
	end

	if device.voice_timer then
		device.voice_timer:cancel()
	end
	device.voice_timer = device.runtime.uloop.timer(function()
		device:send_event("mobiled.voice", {
			event = "call_state_changed",
			call_id = CALL_ID,
			dev_idx = device.dev_idx,
			call_state = "disconnected"
		})
		device.voice_timer = nil
	end, 500)

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

local M = {}

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
