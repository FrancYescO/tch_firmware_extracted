local string, table, tonumber, pcall = string, table, tonumber, pcall

local helper = require("mobiled.scripthelpers")
local json = require("dkjson")
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

local function get_parameter(device, params)
	if not device.web_info.ip then return nil end
	local paramStr = "isTest=false"
	for k, v in pairs(params) do
		paramStr = paramStr .. "&" .. k .. "=" .. v
	end
	local request = string.format("http://%s/goform/goform_get_cmd_process?%s", device.web_info.ip, paramStr)
	local data = curl_get(request, device.web_info.default_headers)
	if data then
		return json.decode(table.concat(data)) or {}
	end
	return {}
end

local function get_parameters(device, params)
	return get_parameter(device, {
		cmd = table.concat(params, "%2C"),
		multi_data = "1"
	})
end

local function set_parameter(device, params, post)
	if not device.web_info.ip then return nil end
	local paramStr = "isTest=false"
	for k, v in pairs(params) do
		paramStr = paramStr .. "&" .. k .. "=" .. v
	end
	local data
	if post then
		local request = string.format("http://%s/goform/goform_set_cmd_process", device.web_info.ip)
		data = curl_post(request, device.web_info.default_headers, paramStr)
	else
		local request = string.format("http://%s/goform/goform_set_cmd_process?%s", device.web_info.ip, paramStr)
		data = curl_get(request, device.web_info.default_headers)
	end
	if data then
		return json.decode(table.concat(data)) or {}
	end
	return {}
end

local function add_device_profile(line, profiles, id, default_profile)
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
		id = id
	}
	if name == default_profile then
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

function Mapper:get_profile_info(device, info)
	local request = {}
	local max_profiles = 19
	for i=0,max_profiles do
		table.insert(request, "APN_config" .. i)
	end
	table.insert(request, "apn_auto_config")
	table.insert(request, "m_profile_name")

	local data = get_parameters(device, request)
	local profiles = {}
	for i=0,max_profiles do
		local line = data["APN_config" .. i]
		if line and #line > 0 then
			add_device_profile(line, profiles, i, data.m_profile_name)
		end
	end
	local line = data["apn_auto_config"]
	if line and #line > 0 then
		add_device_profile(line, profiles, device.auto_profile, data.m_profile_name)
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
		index = tostring(device.modify_profile)
	else
		runtime.log:info("Reusing profile " .. profile.id)
		index = dev_profile_id

		if tonumber(index) == device.auto_profile then
			index = "auto"
		end
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
		index = index
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
	local hardware_version_request = {
		"hardware_version"
	}
	local hardware_version_data = get_parameters(device, hardware_version_request)
	if hardware_version_data.hardware_version then
		local model = string.match(hardware_version_data.hardware_version, "^(.-)-")
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
		elseif model == "MF920VV1" then
			info.radio_interfaces = {
				{ radio_interface = "lte" },
				{ radio_interface = "umts" },
				{ radio_interface = "gsm" },
				{ radio_interface = "auto" }
			}
		end
	end

	local sms_supported_request = {
		"sms_unread_num"
	}
	local sms_supported_data = get_parameters(device, sms_supported_request)
	if sms_supported_data.sms_unread_num ~= "" then
		info.sms_reading = true
		info.sms_sending = true
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
	elseif data.ppp_status == "ppp_connected" or data.ppp_status == "ipv6_connected" or data.ppp_status == "ipv4_ipv6_connected" then
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

local function encode_sms_message(text)
	local result = ""
	for character in text:gmatch("(.)") do
		result = result .. string.format("%04X", character:byte())
	end
	return result
end

local function encode_sms_date(date)
	return os.date("%y;%m;%d;%H;%M;%S;%z", date)
end

function Mapper:send_sms(device, number, message)
	local params = {
		goformId = "SEND_SMS",
		notCallback = "true",
		Number = number,
		sms_time = encode_sms_date(os.time()),
		MessageBody = encode_sms_message(message),
		ID = "-1",
		encode_type = "UNICODE"
	}

	local result = set_parameter(device, params, true)
	if result.result ~= "success" then
		return nil, "sending SMS failed"
	end

	return true
end

function Mapper:delete_sms(device, message_id)
	local params = {
		goformId = "DELETE_SMS",
		msg_id = message_id .. ";",
		notCallback = "true"
	}

	local result = set_parameter(device, params)
	if result.result ~= "success" then
		return nil, "deleting SMS failed"
	end

	return true
end

function Mapper:set_sms_status(device, message_id, status)
	local status_mapping = {
		read = "0",
		unread = "1"
	}

	local params = {
		goformId = "SET_MSG_READ",
		msg_id = message_id .. ";",
		tag = status_mapping[status] or "0",
		notCallback = "0"
	}

	local result = set_parameter(device, params, true)
	if result.result ~= "success" then
		return nil, "setting SMS status failed"
	end

	return true
end

function Mapper:get_sms_info(device)
	-- This call fails when using the multi_data parameter.
	local capacity_data = get_parameter(device, {
		cmd = "sms_capacity_info"
	})

	-- These calls fail when not using the multi_data parameter.
	local unread_data = get_parameters(device, {
		"sms_received_flag",
		"sts_received_flag",
		"sms_unread_num"
	})

	local unread_messages = tonumber(unread_data.sms_unread_num) or 0
	local messages_on_sim = tonumber(capacity_data.sms_sim_rev_total) or 0
	local messages_on_device = tonumber(capacity_data.sms_nv_rev_total) or 0
	local max_messages_on_sim = tonumber(capacity_data.sms_sim_total) or 0
	local max_messages_on_device = tonumber(capacity_data.sms_nv_total) or 0

	local info = {
		read_messages = math.max(messages_on_sim + messages_on_device - unread_messages, 0),
		unread_messages = unread_messages,
		max_messages = max_messages_on_sim + max_messages_on_device
	}

	return info
end

local function decode_sms_message(encoded_text)
	local result = ""
	for digits in encoded_text:gmatch("(%x%x%x%x)") do
		local value = tonumber(digits, 16)
		if value < 256 then
			result = result .. string.char(value)
		end
	end
	return result
end

local function decode_sms_date(date_string)
	local year, month, day, hour, minute, second, timezone = date_string:match("(%d+)[,;](%d+)[,;](%d+)[,;](%d+)[,;](%d+)[,;](%d+)[,;]([+-]%d+)")
	local date = {
		year = tonumber(year) + 2000,
		month = tonumber(month),
		day = tonumber(day),
		hour = tonumber(hour),
		min = tonumber(minute),
		sec = tonumber(second)
	}
	return os.date("%Y-%m-%d %H:%M:%S", os.time(date))
end

function Mapper:get_sms_messages(device)
	local messages = {}

	-- Mem store 0 contains messages on the SIM, mem store 1 contains the messages on the device.
	for mem_store = 0, 1 do
		local data = get_parameter(device, {
			cmd = "sms_data_total",
			page = "0",
			data_per_page = "500",
			mem_store = tostring(mem_store),
			tags = "10",
			order_by = "order+by+id+desc"
		})

		if type(data.messages) == "table" then
			for _, message in ipairs(data.messages) do
				local status = "read"
				if message.tag == "1" then
					status = "unread"
				end

				table.insert(messages, {
					id = tonumber(message.id),
					number = message.number,
					text = decode_sms_message(message.content),
					date = decode_sms_date(message.date),
					status = status,
				})
			end
		end
	end

	return { messages = messages }
end

local function login(device, username, password)
	local params = {
		goformId = "LOGIN",
		password = helper.encode_base64(password)
	}
	set_parameter(device, params)
	return true
end

local function enable_dmz(device)
	local params = {
		goformId = "DMZ_SETTING",
		DMZEnabled = "1",
		DMZIPAddress = device.web_info.local_ip
	}
	set_parameter(device, params, true)
end

function Mapper:configure_device(device, config)
	if config.device.password and not login(device, config.device.username, config.device.password) then
		return false
	end

	enable_dmz(device)
	return true
end

function Mapper:init_device(device)
	if device.web_info.ip then
		device.modify_profile = 5
		device.auto_profile = 99
		device.web_info.default_headers = {
			"Referer: http://" .. device.web_info.ip .. "/index.html",
			"User-Agent: libwebapi" -- Required to make some requests work
		}
		return true
	end
	return nil
end

local function disable_dmz(device)
	local params = {
		goformId = "DMZ_SETTING",
		DMZEnabled = "0"
	}
	set_parameter(device, params, true)
end

function Mapper:destroy_device(device, force)
	if not force then
		disable_dmz(device)
	end

	return nil
end

function M.create(rt, pid)
	runtime = rt

	local mapper = {
		mappings = {
			destroy_device = "runfirst",
			send_sms = "override",
			delete_sms = "override",
			set_sms_status = "override",
			get_sms_info = "override",
			get_sms_messages = "override"
		}
	}

	setmetatable(mapper, Mapper)
	return mapper
end

return M
