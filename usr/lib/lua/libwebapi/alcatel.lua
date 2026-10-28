local json = require("dkjson")
local curl = require("lcurl.safe")
local types = require("mobiled.types")

local runtime

local Mapper = {}
Mapper.__index = Mapper

local M = {}

local function call_method(device, method, arguments, result_type)
	local JSONRPC_VERSION = "2.0"

	local unique_id = string.format("%d", device.web_info.id_generator)
	device.web_info.id_generator = device.web_info.id_generator + 1

	local output_buffer = {}

	local request = curl.easy()
	request:setopt_url(string.format("http://%s/jrd/webapi?api=%s", device.web_info.ip, method))
	request:setopt_post(true)
	request:setopt_httpheader({
		"Content-Type: application/json"
	})
	request:setopt_postfields(json.encode({
		jsonrpc = JSONRPC_VERSION,
		method = method,
		params = arguments or {},
		id = unique_id,
	}))
	request:setopt_writefunction(table.insert, output_buffer)
	request:perform()
	request:close()

	local reply = json.decode(table.concat(output_buffer))
	if not reply or reply.jsonrpc ~= JSONRPC_VERSION or reply.id ~= unique_id then
		runtime.log:debug("%s(%s) failed", method, json.encode(arguments or {}))
		return nil
	end

	local result = reply.result
	if result_type then
		local success, checked_result = types.dictionary(result_type)(string.format("result of %s", method), result)
		if not success then
			runtime.log:debug("%s(%s) returned invalid result: %s", method, json.encode(arguments or {}), checked_result)
			return nil
		end
		result = checked_result
	end

	runtime.log:debug("%s(%s) returned %s", method, json.encode(arguments or {}), json.encode(result))
	return result
end

function Mapper:get_sim_info(device, info)
	local sim_status = call_method(device, "GetSimStatus", {}, {
		PinState = types.integer()
	})
	if not sim_status then
		return nil, "failed to call GetSimStatus"
	end

	if sim_status.PinState == 1 then
		info.sim_state = "locked"
	elseif sim_status.PinState == 2 or sim_status.PinState == 3 then
		info.sim_state = "ready"
	elseif sim_status.PinState == 4 then
		info.sim_state = "blocked"
	elseif sim_status.PinState == 5 then
		info.sim_state = "permanently_blocked"
	else
		info.sim_state = "not_present"
	end

	return true
end

function Mapper:get_pin_info(device, info)
	local sim_status = call_method(device, "GetSimStatus", {}, {
		PinState = types.integer(),
		PinRemainingTimes = types.integer(),
		PukRemainingTimes = types.integer()
	})
	if not sim_status then
		return nil, "failed to call GetSimStatus"
	end

	info.unlock_retries_left = sim_status.PinRemainingTimes
	info.unblock_retries_left = sim_status.PukRemainingTimes

	if sim_status.PinState == 1 then
		info.pin_state = "enabled_not_verified"
	elseif sim_status.PinState == 2 then
		info.pin_state = "enabled_verified"
	elseif sim_status.PinState == 3 then
		info.pin_state = "disabled"
	elseif sim_status.PinState == 4 or sim_status.PinState == 5 then
		info.pin_state = "blocked"
	end

	-- Workaround to avoid error during successful unblock pin
	-- PUK remaining times during unblock / block states are different
	-- setting the value to 10 to maintain the same value during unblock state
	if sim_status.PinState <= 3 then
		info.unblock_retries_left = 10
	end

	return true
end

function Mapper:unlock_pin(device, pin_type, pin) -- luacheck: no unused args
	return not not call_method(device, "UnlockPin", {Pin = pin})
end

function Mapper:unblock_pin(device, pin_type, puk, newpin) -- luacheck: no unused args
	local sim_status = call_method(device, "GetSimStatus", {}, {
		PinState = types.integer()
	})
	if sim_status and sim_status.PinState <= 3 then
		return nil, "Operation not permitted in enabled/disabled state"
	end
	return not not call_method(device, "UnlockPuk", {Puk = puk, Pin = newpin})
end

function Mapper:change_pin(device, pin_type, pin, newpin) -- luacheck: no unused args
	return not not call_method(device, "ChangePinCode", {CurrentPin = pin, NewPin = newpin})
end

function Mapper:enable_pin(device, pin_type, pin) -- luacheck: no unused args
	return not not call_method(device, "ChangePinState", {State = 1, Pin = pin})
end

function Mapper:disable_pin(device, pin_type, pin) -- luacheck: no unused args
	return not not call_method(device, "ChangePinState", {State = 0, Pin = pin})
end

function Mapper:get_session_info(device, info, session_id) -- luacheck: no unused args
	local connection_state = call_method(device, "GetConnectionState", {}, {
		ConnectionStatus = types.integer(),
		UlBytes = types.optional(types.integer()),
		DlBytes = types.optional(types.integer()),
		ConnectionTime = types.optional(types.integer()),
		IPv4Adrress = types.optional(types.string()),
		IPv6Adrress = types.optional(types.string())
	})
	if not connection_state then
		return nil
	end
	local lan_settings = call_method(device, "GetLanSettings", {}, {
		DNSAddress1 = types.string(),
		DNSAddress2 = types.string()
	})
	if not lan_settings then
		return nil
	end

	if connection_state.ConnectionStatus == 1 then
		info.session_state = "connecting"
	elseif connection_state.ConnectionStatus == 2 then
		info.session_state = "connected"
		info.packet_counters = {
			tx_bytes = connection_state.UlBytes,
			rx_bytes = connection_state.DlBytes
		}
		info.duration = connection_state.ConnectionTime
	else
		info.session_state = "disconnected"
	end

	info.proto = "router"
	info.router = {
		ipv4_addr = connection_state.IPv4Adrress,
		ipv6_addr = connection_state.IPv6Adrress,
		ipv4_gw = device.web_info.ip,
		ipv4_dns1 = lan_settings.DNSAddress1,
		ipv4_dns2 = lan_settings.DNSAddress2
	}

	return true
end

function Mapper:start_data_session(device, session_id, profile) -- luacheck: no unused args
	return not not call_method(device, "Connect", {})
end

function Mapper:stop_data_session(device, session_id) -- luacheck: no unused args
	return not not call_method(device, "DisConnect", {})
end

function Mapper:set_power_mode(device, mode)
	if mode == "lowpower" or mode == "airplane" then
		-- We cannot set the power mode but the least we can do is disconnect.
		return not not call_method(device, "DisConnect", {})
	end
	return true
end

function Mapper:get_device_capabilities(device, info)
	info.radio_interfaces = {
		{ radio_interface = "lte" },
		{ radio_interface = "umts" },
		{ radio_interface = "gsm" },
		{ radio_interface = "auto" }
	}

	info.reuse_profiles = true
	info.supported_auth_types = "none pap chap papchap"
	info.supported_pdp_types = { "ipv4", "ipv6", "ipv4v6" }

	return true
end

function Mapper:get_device_info(device, info)
	local system_info = call_method(device, "GetSystemInfo", {}, {
		HwVersion = types.string(),
		SwVersion = types.string(),
		DeviceName = types.string(),
		IMEI = types.string(),
		sn = types.string()
	})
	if not system_info then
		return nil
	end

	info.device_config_parameter = "imei"
	info.hardware_version = system_info.HwVersion:match("^%s*(.-)%s*$")
	info.software_version = system_info.SwVersion:match("^%s*(.-)%s*$")
	info.model = system_info.DeviceName:match("^%s*(.-)%s*$")
	info.imei = system_info.IMEI:match("^%s*(.-)%s*$")
	info.serial = system_info.sn:match("^%s*(.-)%s*$")
	info.manufacturer = "Alcatel"

	return true
end

function Mapper:get_radio_signal_info(device, info)
	local system_status = call_method(device, "GetSystemStatus", {}, {
		NetworkType = types.integer()
	})
	if not system_status then
		return nil
	end
	local network_info = call_method(device, "GetNetworkInfo", {}, {
		RSRP = types.number_string(types.real()),
		RSRQ = types.number_string(types.real()),
		SINR = types.number_string(types.real()),
		RSSI = types.number_string(types.real()),
		EcIo = types.number_string(types.real()),
		TxPWR = types.number_string(types.real())
	})
	if not network_info then
		return nil
	end

	local RADIO_INTERFACES = {
		[0] = "no_service",
		[1] = "gsm",
		[2] = "gsm",
		[3] = "hspa",
		[4] = "hspa",
		[5] = "umts",
		[6] = "hspa",
		[7] = "hspa",
		[8] = "lte",
		[9] = "lte"
	}
	info.radio_interface = RADIO_INTERFACES[system_status.NetworkType] or "no_service"

	info.rsrp = network_info.RSRP
	info.rsrq = network_info.RSRQ
	info.sinr = network_info.SINR
	info.rssi = network_info.RSSI
	info.ecio = network_info.EcIo
	info.tx_power = network_info.TxPWR

	return true
end

function Mapper:get_network_info(device, info)
	local connection_settings = call_method(device, "GetConnectionSettings", {}, {
		NetworkName = types.optional(types.string())
	})
	if not connection_settings then
		return nil
	end
	local system_status = call_method(device, "GetSystemStatus", {}, {
		NetworkType = types.integer(),
		Roaming = types.integer()
	})
	if not system_status then
		return nil
	end
	local network_info = call_method(device, "GetNetworkInfo", {}, {
		PLMN = types.string(),
		CellId = types.number_string(types.integer()),
		SpnName = types.string()
	})
	if not network_info then
		return nil
	end

	if system_status.NetworkType == 0 then
		info.nas_state = "not_registered"
		info.ps_state = "detached"
		info.cs_state = "detached"
	else
		info.nas_state = "registered"
		info.ps_state = "attached"
		info.cs_state = "attached"
	end

	info.plmn_info = {
		description = connection_settings.NetworkName,
		mcc = network_info.PLMN:sub(1, 3),
		mnc = network_info.PLMN:sub(4)
	}

	info.service_provider = {
		name = network_info.SpnName
	}

	info.cell_id = network_info.CellID

	if system_status.Roaming == 1 then
		info.roaming = "home"
	else
		info.roaming = "roaming"
	end

	return true
end

local function get_profile_list(device)
	local result = call_method(device, "GetProfileList", {}, {
		ProfileList = types.list(types.dictionary({
			ProfileName = types.string(),
			ProfileID = types.integer(),
			APN = types.string(),
			UserName = types.string(),
			Password = types.string(),
			AuthType = types.integer(),
			PdpType = types.integer()
		}))
	})
	return result and result.ProfileList
end

local function configure_profile(device, name, profile)
	local AUTH_TYPES = {
		none = 0,
		pap = 1,
		chap = 2,
		papchap = 3
	}
	local PDP_TYPES = {
		ipv4 = 0,
		ipv6 = 2,
		ipv4v6 = 3
	}

	local method = "AddNewProfile"
	local arguments = {
		ProfileName = name,
		APN = profile.apn or "",
		UserName = profile.username or "",
		Password = profile.password or "",
		AuthType = AUTH_TYPES[profile.authentication] or 0,
		DailNumber = "*99#",
		IPAdrress = "",
		PdpType = PDP_TYPES[profile.pdptype] or 3
	}

	local profile_list = get_profile_list(device)
	if profile_list then
		for _, profile_info in ipairs(profile_list) do
			if profile_info.ProfileName == name then
				method = "EditProfile"
				arguments.ProfileID = profile_info.ProfileID
				break
			end
		end
	end

	return not not call_method(device, method, arguments)
end

local function select_profile(device, name)
	local profile_list = get_profile_list(device)
	if not profile_list then
		return nil
	end

	for _, profile in ipairs(profile_list) do
		if profile.ProfileName == name then
			return not not call_method(device, "SetDefaultProfile", {ProfileID = profile.ProfileID})
		end
	end

	return nil
end

function Mapper:set_attach_params(device, profile) -- luacheck: no unused args
	local PDP_TYPES = {
		ipv4 = 0,
		ipv6 = 2,
		ipv4v6 = 3
	}

	-- Disconnect the session before updating profile in the dongle
	call_method(device, "DisConnect", {})

	local profile_name = string.match(profile.id, "^device:(.*)$")
	if not profile_name then
		local INTERNAL_PROFILE = "Technicolor"
		if not configure_profile(device, INTERNAL_PROFILE, profile) then
			return nil
		end
		profile_name = INTERNAL_PROFILE
	end
	return not not call_method(device, "SetConnectionSettings", {
		PdpType = PDP_TYPES[profile.pdptype] or 3,
		RoamingConnect = 1,
		ConnectMode = 1
	}) and select_profile(device, profile_name)
end

function Mapper:get_profile_info(device, info)
	local profile_list = {}
	local AUTH_TYPES_STR = {
		[0] = "none",
		[1] = "pap",
		[2] = "chap",
		[3] = "papchap"
	}
	local PDP_TYPES_STR = {
		[0] = "ipv4",
		[2] = "ipv6",
		[3] = "ipv4v6"
	}

	local ProfileList = get_profile_list(device)

	if not ProfileList then
		return false
	end

	for _, profile_info in ipairs(ProfileList) do
		local entry = {
			name = profile_info.ProfileName,
			apn = profile_info.APN,
			id = profile_info.ProfileID,
			username = profile_info.UserName,
			password = profile_info.Password,
			authentication = AUTH_TYPES_STR[profile_info.AuthType] or "none",
			pdptype = PDP_TYPES_STR[profile_info.PdpType] or "ipv4"
		}

		-- Technicolor profile is same as profile[0] in UCI configuration
		-- and it should not be shown when reuse_profiles=1
		if profile_info.ProfileName ~= "Technicolor" then
			table.insert(profile_list, entry)
		end
	end

	info.profiles = profile_list

	return true
end

function Mapper:network_attach(device) -- luacheck: no unused args
	return true
end

function Mapper:network_detach(device) -- luacheck: no unused args
	return true
end

function Mapper:init_device(device)
	if device.web_info.ip then
		device.web_info.id_generator = 1
		return true
	end
end

function Mapper:destroy_device(device, force) -- luacheck: no unused args
	return true
end

function M.create(rt, pid) -- luacheck: no unused args
	runtime = rt

	local mapper = {
		mappings = {
		}
	}

	setmetatable(mapper, Mapper)
	return mapper
end

return M
