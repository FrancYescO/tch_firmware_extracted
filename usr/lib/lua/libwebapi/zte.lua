local string, table, tonumber, pcall = string, table, tonumber, pcall

local json = require ("dkjson")
local cURL = require("cURL")

local runtime

local Mapper = {}
Mapper.__index = Mapper

local M = {}

local function curl_get(url, headers)
	local curl = cURL.easy_init()
	curl:setopt_url(url)
	curl:setopt_timeout(5)
	curl:setopt_httpheader(headers)
	local t = {}
	local result = pcall(curl.perform, curl, { writefunction=function(buf) table.insert(t, buf) end })
	if not result then return nil end
	return t
end

local function curl_post(url, headers, post_data)
	local curl = cURL.easy_init()
	curl:setopt_url(url)
	curl:setopt_timeout(5)
	curl:setopt_httpheader(headers)
	curl:setopt_post(1)
	curl:setopt_postfields(post_data)
	curl:setopt_postfieldsize(#post_data)
	local t = {}
	local result = pcall(curl.perform, curl, { writefunction=function(buf) table.insert(t, buf) end })
	if not result then return nil end
	return t
end

local function get_parameters(device, params)
	if not device.web_info.ip then return nil end
	local request = string.format("http://%s/goform/goform_get_cmd_process?isTest=false&cmd=%s&multi_data=1", device.web_info.ip, table.concat(params, "%2C"))
	local data = curl_get(request, device.web_info.default_headers)
	if data then
		return json.decode(table.concat(data))
	end
	return {}
end

local function set_parameter(device, params, post)
	local paramList = {
		isTest = false
	}
	for k, v in pairs(params) do
		table.insert(paramList, k .. "=" .. v)
	end
	local paramStr = table.concat(paramList, "&")
	local data
	if post then
		local request = string.format("http://%s/goform/goform_set_cmd_process", device.web_info.ip)
		data = curl_post(request, device.web_info.default_headers, paramStr)
	else
		local request = string.format("http://%s/goform/goform_set_cmd_process?%s", device.web_info.ip, paramStr)
		data = curl_get(request, device.web_info.default_headers)
	end
	if data then
		return json.decode(table.concat(data))
	end
	return {}
end

function Mapper:get_profile_info(device, info)
	local request = {}
	local max_profiles = 19
	for i=0,max_profiles do
		table.insert(request, "APN_config" .. i)
	end
	table.insert(request, "m_profile_name")

	local data = get_parameters(device, request)
	local profiles = {}
	for i=0,max_profiles do
		local line = data["APN_config" .. i]
		if line  and #line > 0 then
			local name, apn, _, _, authentication, username, password, pdptype = string.match(line, "(.-)%($%)(.-)%($%)(.-)%($%)(.-)%($%)(.-)%($%)(.-)%($%)(.-)%($%)(.-)%($%)(.-)%($%)(.-)%($%)(.-)%($%)(.-)%($%)")
			if #authentication == 0 then authentication = nil end
			if #username == 0 then username = nil end
			if #password == 0 then password = nil end
			local profile = {
				name = name,
				apn = apn,
				authentication = authentication,
				username = username,
				password = password,
				id = i
			}
			if name == data.m_profile_name then
				profile.default = true
			end
			if pdptype == "IP" then
				profile.pdptype = "ipv4"
			elseif pdptype == "IPv6" then
				profile.pdptype = "ipv6"
			else
				profile.pdptype = "ipv4v6"
			end
			table.insert(profiles,  profile)
		end
	end
	info.profiles = profiles
	return true
end

local function add_profile(device, index, profile)
	local pdptype
	if profile.pdptype == "ipv4" then
		pdptype = "IP"
	elseif profile.pdptype == "ipv6" then
		pdptype = "IPv6"
	else
		pdptype = "IPv4v6"
	end

	local params = {
		goformId = "APN_PROC_EX",
		apn_action = "save",
		apn_mode = "manual",
		profile_name = profile.name,
		wan_dial = "*99#",
		apn_select = "manual",
		pdp_type = pdptype,
		pdp_select = "auto",
		pdp_addr = "",
		index = tostring(index),
		wan_apn = profile.apn,
		ppp_auth_mode = profile.authentication or "none",
		ppp_username = profile.username or "",
		ppp_passwd = profile.password or "",
		dns_mode = "auto",
		prefer_dns_manual = "",
		standby_dns_manual = ""
	}
	set_parameter(device, params, true)
end

local function delete_profile(device, index)
	local params = {
		goformId = "APN_PROC_EX",
		apn_action = "delete",
		apn_mode = "manual",
		index = tostring(index)
	}
	set_parameter(device, params)
end

function Mapper:start_data_session(device, session_id, profile)
	local index
	local dev_profile_id = string.match(profile.id, "^device:(.*)$")
	if not dev_profile_id then
		runtime.log:info("Adding new profile " .. profile.id)
		delete_profile(device, device.modify_profile)
		add_profile(device, device.modify_profile, profile)
		index = device.modify_profile
	else
		runtime.log:info("Reusing profile " .. profile.id)
		index = dev_profile_id
	end

	local pdptype
	if profile.pdptype == "ipv4" then
		pdptype = "IP"
	elseif profile.pdptype == "ipv6" then
		pdptype = "IPv6"
	else
		pdptype = "IPv4v6"
	end

	local params = {
		goformId = "APN_PROC_EX",
		apn_mode = "manual",
		apn_action = "set_default",
		set_default_flag = "1",
		pdp_type = pdptype,
		index = tostring(index)
	}

	set_parameter(device, params)
	set_parameter(device, { goformId = "CONNECT_NETWORK" })
	return true
end

function Mapper:stop_data_session(device, session_id)
	set_parameter(device, { goformId = "DISCONNECT_NETWORK" })
	return true
end

function Mapper:get_device_capabilities(device, info)
	local request = {
		"hardware_version"
	}
	local data = get_parameters(device, request)
	if data.hardware_version then
		local model = string.match(data.hardware_version, "^(.-)-")
		if model == "MF730M" then
			info.radio_interfaces = {
				{ radio_interface = "gsm" },
				{ radio_interface = "umts" },
				{ radio_interface = "auto" }
			}
		elseif model == "MF823" then
			info.radio_interfaces = {
				{ radio_interface = "lte" },
				{ radio_interface = "umts" },
				{ radio_interface = "auto" }
			}
		end
	end

	info.reuse_profiles = true
	return true
end

function Mapper:get_device_info(device, info)
	local request = {
		"imei",
		"hardware_version",
		"wa_inner_version"
	}
	local data = get_parameters(device, request)
	info.device_config_parameter = "imei"
	info.imei = data.imei
	info.hardware_version = data.hardware_version
	info.software_version = data.wa_inner_version
	if data.hardware_version then
		info.model = string.match(data.hardware_version, "^(.-)-")
	end
	info.manufacturer = "ZTE"
	return true
end

function Mapper:get_session_info(device, info, session_id)
	local request = {
		"ppp_status",
		"realtime_tx_bytes",
		"realtime_rx_bytes",
		"realtime_time",
		"wan_ipaddr"
	}
	local data = get_parameters(device, request)
	if data.ppp_status == "ppp_connecting" then
		info.session_state = "connecting"
	elseif data.ppp_status == "ppp_connected" then
		info.session_state = "connected"
		info.packet_counters = {
			tx_bytes = data.realtime_tx_bytes,
			rx_bytes = data.realtime_rx_bytes,
		}
		info.duration = data.realtime_time
	else
		info.session_state = "disconnected"
	end

	info.proto = "router"
	info.router = {
		ipv4_addr = data.wan_ipaddr,
		ipv4_gw = device.web_info.ip,
		ipv4_dns1 = device.web_info.ip
	}
	return true
end

function Mapper:get_radio_signal_info(device, info)
	local request = {
		"network_type",
		"rssi",
		"rscp",
		"ecio",
		"lte_rsrp"
	}
	local data = get_parameters(device, request)
	if data.network_type then
		if string.match(data.network_type, "HSPA") or data.network_type == "UMTS" then
			info.radio_interface = "umts"
		elseif data.network_type == "LTE" then
			info.radio_interface = "lte"
		elseif data.network_type == "EDGE" then
			info.radio_interface = "gsm"
		elseif data.network_type == "NO_SERVICE" then
			info.radio_interface = "no_service"
		end
	end
	if data.rssi ~= "" then info.rssi = data.rssi end
	if data.ecio ~= "" and data.ecio ~= "1000" then info.ecio = data.ecio end
	if data.rscp ~= "" and data.rscp ~= "-500" then info.rscp = data.rscp end
	if data.lte_rsrp ~= "" then info.rsrp = data.lte_rsrp end
	return true
end

function Mapper:get_network_info(device, info)
	local request = {
		"network_provider",
		"simcard_roam",
		"network_type",
		"domain_stat"
	}
	local data = get_parameters(device, request)
	info.plmn_info = {
		description = data.network_provider,
		mcc = "",
		mnc = ""
	}
	if data.simcard_roam == "Home" then
		info.roaming = "home"
	elseif data.simcard_roam == "Roaming" then
		info.roaming = "roaming"
	end
	if data.network_type ~= "NO_SERVICE" then
		info.nas_state = "registered"
	else
		info.nas_state = "not_registered"
	end
	if data.domain_stat == "CS_PS" then
		info.ps_state = "attached"
		info.cs_state = "attached"
	elseif data.domain_stat == "CS" then
		info.ps_state = "detached"
		info.cs_state = "attached"
	elseif data.domain_stat == "PS" then
		info.ps_state = "attached"
		info.cs_state = "detached"
	end
	return true
end

local function sim_state_from_modem_main_state(state)
	if state == "modem_waitpin" then
		return "locked"
	elseif state == "modem_sim_undetected" then
		return "not_present"
	elseif state == "modem_waitpuk" then
		return "blocked"
	elseif state == "modem_sim_destroy" then
		return "permanently_blocked"
	end
	return "ready"
end

function Mapper:get_sim_info(device, info)
	local request = {
		"modem_main_state",
		"sim_imsi",
		"msisdn"
	}
	local data = get_parameters(device, request)
	info.sim_state = sim_state_from_modem_main_state(data.modem_main_state)
	if data.sim_imsi and data.sim_imsi ~= "" then
		info.imsi = data.sim_imsi
	end
	if data.msisdn and data.msisdn ~= "" then
		info.msisdn = data.msisdn
	end
	info.iccid_before_unlock = false
	return true
end

function Mapper:get_pin_info(device, info)
	local request = {
		"pinnumber",
		"puknumber",
		"pin_status",
		"modem_main_state"
	}
	local data = get_parameters(device, request)
	info.unlock_retries_left = data.pinnumber
	info.unblock_retries_left = data.puknumber
	if tonumber(data.pin_status) == 0 then
		info.pin_state = "disabled"
	elseif tonumber(data.pin_status) == 1 or data.pin_status == "" then
		local sim_state = sim_state_from_modem_main_state(data.modem_main_state)
		if sim_state == "locked" then
			info.pin_state = "enabled_not_verified"
		elseif sim_state == "blocked" or sim_state == "permanently_blocked" then
			info.pin_state = "blocked"
		elseif sim_state == "ready" then
			info.pin_state = "enabled_verified"
		end
	end
	return true
end

function Mapper:unlock_pin(device, pin_type, pin)
	local params = {
		goformId = "ENTER_PIN",
		PinNumber = pin,
		pin_save_flag = "0"
	}
	return set_parameter(device, params)
end

function Mapper:unblock_pin(device, pin_type, pin)
	local params = {
		goformId = "ENTER_PUK",
		PinNumber = pin,
		pin_save_flag = "0"
	}
	return set_parameter(device, params)
end

function Mapper:change_pin(device, pin_type, pin, newpin)
	local params = {
		goformId = "ENABLE_PIN",
		OldPinNumber = pin,
		NewPinNumber = newpin,
		pin_save_flag = "0"
	}
	return set_parameter(device, params)
end

function Mapper:enable_pin(device, pin_type, pin)
	local params = {
		goformId = "ENABLE_PIN",
		OldPinNumber = pin,
		pin_save_flag = "0"
	}
	return set_parameter(device, params)
end

function Mapper:disable_pin(device, pin_type, pin)
	local params = {
		goformId = "DISABLE_PIN",
		OldPinNumber = pin,
		pin_save_flag = "0"
	}
	return set_parameter(device, params)
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

	local params = {
		goformId = "SET_BEARER_PREFERENCE",
	}

	if selected_radio.type == "auto" then
		params.BearerPreference = "NETWORK_auto"
	elseif selected_radio.type == "lte" then
		params.BearerPreference = "Only_LTE"
	elseif selected_radio.type == "umts" then
		params.BearerPreference = "Only_WCDMA"
	elseif selected_radio.type == "gsm" then
		params.BearerPreference = "Only_GSM"
	end

	return set_parameter(device, params)
end

function Mapper:network_scan(device, start)
	if start then
		local params = {
			goformId = "SCAN_NETWORK"
		}
		set_parameter(device, params)
		device.network_scan_duration = nil
		device.network_scan_list = nil
		device.network_scan_start_time = os.time()
		return { scanning = true }
	else
		local request = {
			"m_netselect_status",
			"m_netselect_contents"
		}
		local data = get_parameters(device, request)
		if data.m_netselect_status == "manual_selecting" then
			return { scanning = true }
		end

		if device.network_scan_start_time then
			device.network_scan_duration = os.difftime(os.time(), device.network_scan_start_time)
			device.network_scan_start_time = nil
		end

		if data.m_netselect_contents and not device.network_scan_list then
			device.network_scan_list = {}
			for section in string.gmatch(data.m_netselect_contents, '([^;]+)') do
				local entry = {}
				local stat, description, plmn, radio_interface = string.match(section, "(.-),(.-),(.-),(.+)")
				if stat == "2" then
					entry.roaming_state = "home"
					entry.preferred = true
					entry.forbidden = false
					entry.used = true
				elseif stat == "1" then
					entry.roaming_state = "roaming"
					entry.preferred = false
					entry.forbidden = false
					entry.used = false
				elseif stat == "3" then
					entry.roaming_state = "roaming"
					entry.preferred = false
					entry.forbidden = true
					entry.used = false
				end
				entry.plmn_info = {}
				if plmn then
					entry.plmn_info.mcc = string.sub(plmn, 1, 3)
					entry.plmn_info.mnc = string.sub(plmn, 4)
				end
				entry.plmn_info.description = description
				radio_interface = tonumber(radio_interface)
				if radio_interface then
					if radio_interface >= 0 and radio_interface <= 3 and radio_interface ~= 2 then
						entry.radio_interface = "gsm"
					elseif radio_interface == 2 or (radio_interface >= 4 and radio_interface <= 6) then
						entry.radio_interface = "umts"
					elseif radio_interface == 7 then
						entry.radio_interface = "lte"
					else
						entry.radio_interface = "no service"
					end
				end
				table.insert(device.network_scan_list, entry)
			end
		end
		return {
			duration = device.network_scan_duration or 0,
			network_scan_list = device.network_scan_list,
			scanning = false
		}
	end
end

function Mapper:init_device(device)
	if device.web_info.ip then
		device.modify_profile = 5
		device.web_info.default_headers = { "Referer: http://" .. device.web_info.ip .. "/index.html" }
		return true
	end
	return nil
end

function M.create(rt, pid)
	runtime = rt

	local mapper = {
		mappings = {}
	}

	setmetatable(mapper, Mapper)
	return mapper
end

return M
