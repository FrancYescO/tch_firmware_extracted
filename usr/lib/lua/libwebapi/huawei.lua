local string, tonumber, type, table, pcall, pairs = string, tonumber, type, table, pcall, pairs

local helper = require("mobiled.scripthelpers")
local lom = require("lxp.lom")
local cURL = require("cURL")

local runtime

local Mapper = {}
Mapper.__index = Mapper

local M = {}

local huawei_errors = {
	["1"] = "Failed to get tokens",
	["100002"] = "Not supported",
	["100003"] = "Not allowed",
	["100004"] = "System busy",
	["108001"] = "Wrong username",
	["108002"] = "Wrong password",
	["108003"] = "Already logged in",
	["108006"] = "Login username/password wrong",
	["108007"] = "Maximum number of logins with wrong username/password",
	["120001"] = "Voice busy",
	["125001"] = "Wrong token",
	["125002"] = "Wrong session",
	["125003"] = "Wrong session token",
	["103002"] = "PIN already unlocked"
}
setmetatable(huawei_errors, { __index = function() return "Unknown error" end })

local function log_error(error)
	runtime.log:error(string.format('Received error code "%d" (%s)', error, huawei_errors[error]))
end

local function get_from_table(data, tag)
	if type(data) ~= "table" then return nil end
	for k, v in pairs(data) do
		if v.tag == tag then return v end
	end
	return nil
end

local function get_error(data)
	local response = lom.parse(data)
	if type(response) == "table" then
		local code = get_from_table(response, "code")
		if type(code) == "table" then
			return code[1]
		end
	end
	return nil
end

local function curl_get(device, url, timeout)
	local curl = cURL.easy_init()
	if device.web_info and device.web_info.cookie_store then
		curl:setopt_share(device.web_info.cookie_store)
	end
	curl:setopt_url(url)
	curl:setopt_timeout(timeout or 5)
	curl:setopt_httpheader({"Content-Type: text/xml"})

	runtime.log:debug("GET: " .. url)

	local t = {}
	local result = pcall(curl.perform, curl, { writefunction = function(buf) table.insert(t, buf) end })
	if not result then return nil end
	local data = table.concat(t, "")

	local error = get_error(data)
	if error then
		runtime.log:debug(data)
		return nil, error
	end
	return data
end

local function get_tokens(device)
	local data = curl_get(device, string.format("http://%s/html/index.html", device.web_info.ip))
	local tokens = {}
	if data then
		for token in string.gmatch(data, '"csrf_token"%s+content="(.-)"') do
			table.insert(tokens, token)
		end
		if #tokens == 0 then
			return nil, "unavailable"
		end
	end
	return tokens
end

local function curl_post(device, raw_url, content, timeout)
	local url = string.format(raw_url, device.web_info.ip)

	local curl = cURL.easy_init()
	if device.web_info and device.web_info.cookie_store then
		runtime.log:info("Reusing cookie store")
		curl:setopt_share(device.web_info.cookie_store)
	end

	curl:setopt_post(1)
	curl:setopt_url(url)
	curl:setopt_timeout(timeout or 5)
	runtime.log:debug("POST: " .. url)

	local headers
	if device.web_info.uses_tokens then
		-- Check if we still have tokens available
		if not device.web_info.tokens or #device.web_info.tokens == 0 then
			local tokens = get_tokens(device)
			if not tokens or #tokens == 0 then
				return nil, "1"
			end
			device.web_info.tokens = tokens
		end

		headers = { "Content-Type: application/x-www-form-urlencoded; charset=UTF-8",
			"__RequestVerificationToken: " .. device.web_info.tokens[1],
			"X-Requested-With: XMLHttpRequest",
			"Accept-Encoding: gzip, deflate" }
		-- Token has been used, remove it
		table.remove(device.web_info.tokens, 1)
	else
		headers = { "Content-Type: application/x-www-form-urlencoded; charset=UTF-8",
			"X-Requested-With: XMLHttpRequest",
			"Accept-Encoding: gzip, deflate" }
	end

	for _, h in pairs(headers) do
		runtime.log:debug(h)
	end

	runtime.log:debug(content)

	curl:setopt_httpheader(headers)
	curl:setopt_postfields(content)

	local t = {}
	local result = pcall(curl.perform, curl, { writefunction = function(buf) table.insert(t, buf) end })
	if not result then return nil end
	local data = table.concat(t, "")
	runtime.log:debug(data)

	local error = get_error(data)
	if error then
		return nil, error
	end
	return true
end

local function capture(cmd, raw)
	local f = assert(io.popen(cmd, 'r'))
	local s = assert(f:read('*a'))
	f:close()
	if raw then return s end
	s = string.gsub(s, '%s+', '')
	s = string.gsub(s, '%s+$', '')
	s = string.gsub(s, '[\n\r]+', ' ')
	return s
end

local function add_error(device, severity, error_type, error_message)
	local uptime = helper.uptime()
	if #device.errors > 20 then
		table.remove(device.errors, 1)
	end
	local error = {
		severity = severity,
		type = error_type,
		message = error_message,
		uptime = uptime
	}
	table.insert(device.errors, error)
end

local function login(device, username, password)
	local content = '<?xml version="1.0" encoding="UTF-8"?>' ..
					'<request>' ..
						'<Username>' .. username .. '</Username>' ..
						'<password_type>4</password_type>' ..
						'<Password>%s</Password>' ..
					'</request>'

	-- Check if we still have tokens available
	if not device.web_info.tokens or #device.web_info.tokens == 0 then
		local tokens = get_tokens(device)
		if not tokens or #tokens == 0 then
			return nil, "Failed to get tokens"
		end
		device.web_info.tokens = tokens
	end

	local pass = capture("echo -n " .. password .. " | sha256sum | cut -d ' ' -f 1 | tr -d '\n' | base64")
	pass = capture("echo -n " .. username .. pass .. device.web_info.tokens[1] .. " | sha256sum | cut -d ' ' -f 1 | tr -d '\n' | base64")
	local ret, error = curl_post(device, "http://%s/api/user/login", string.format(content, pass), 5)
	if not ret and error then
		if error == "108006" then
			add_error(device, "error", "wrong_username_password", "Wrong username or password")
		elseif error == "108007" then
			add_error(device, "error", "wrong_username_password_max_tries", "Maximum username/password tries reached")
		end
		log_error(error)
	else
		device.buffer.device_info.login_required = false
		device.web_info.tokens = get_tokens(device)
	end
	return ret, error
end

function Mapper:get_device_info(device, info)
	info.device_config_parameter = "model"
	info.power_mode = "online"
	local data, error = curl_get(device, string.format("http://%s/api/device/basic_information", device.web_info.ip))
	if data then
		local tab = lom.parse(data)
		if tab then
			local i = get_from_table(tab, "devicename")
			if i then device.buffer.device_info.model = i[1] end
		end
	elseif error then
		log_error(error)
	end
	data, error = curl_get(device, string.format("http://%s/api/device/information", device.web_info.ip))
	if data then
		local tab = lom.parse(data)
		if tab then
			local i = get_from_table(tab, "DeviceName")
			if i then device.buffer.device_info.model = i[1] end
			i = get_from_table(tab, "Imei")
			if i then device.buffer.device_info.imei = i[1] end
			i = get_from_table(tab, "ImeiSvn")
			if i and device.buffer.device_info.imei then
				device.buffer.device_info.imeisv = string.sub(device.buffer.device_info.imei, 1, 14) .. i[1]
			end
			i = get_from_table(tab, "SerialNumber")
			if i then device.buffer.device_info.serial = i[1] end
			i = get_from_table(tab, "HardwareVersion")
			if i then device.buffer.device_info.hardware_version = i[1] end
			i = get_from_table(tab, "SoftwareVersion")
			if i then device.buffer.device_info.software_version = i[1] end
			i = get_from_table(tab, "Imsi")
			if i then device.buffer.sim_info.imsi = i[1] end
			i = get_from_table(tab, "Iccid")
			if i then
				local iccid = i[1]
				if iccid and string.sub(iccid, 20, 20) == "F" then
					iccid = string.sub(iccid, 1, 19)
				end
				device.buffer.sim_info.iccid = iccid
			end
			i = get_from_table(tab, "Msisdn")
			if i then device.buffer.sim_info.msisdn = i[1] end
			i = get_from_table(tab, "supportmode")
			if i and i[1] then
				local radio_interfaces = {
					{ radio_interface = "auto" }
				}
				for radio in string.gmatch(i[1], "([^|]+)") do
					if radio == "LTE" then table.insert(radio_interfaces, { radio_interface = "lte" })
					elseif radio == "WCDMA" then table.insert(radio_interfaces, { radio_interface = "umts" })
					elseif radio == "GSM" then table.insert(radio_interfaces, { radio_interface = "gsm" }) end
				end
				device.buffer.device_capabilities.radio_interfaces = radio_interfaces
			end
			return true
		end
	elseif error then
		log_error(error)
		if error == "100003" then
			device.buffer.device_info.login_required = true
		end
		return true
	end
	return nil, "Failed to get device info"
end

function Mapper:get_sim_info(device, info)
	-- ICCID and IMSI come in via the device info
	self:get_device_info(device, {})

	local data, error = curl_get(device, string.format("http://%s/api/pin/status", device.web_info.ip))
	if data then
		local tab = lom.parse(data)
		if tab then
			local i = get_from_table(tab, "SimState")
			if i then 
				if i[1] == "258" or i[1] == "257" then info.sim_state = "ready"
				elseif i[1] == "255" then info.sim_state = "not_present"
				elseif i[1] == "260" then info.sim_state = "locked"
				elseif i[1] == "261" then info.sim_state = "blocked"
				else info.sim_state = "error" end
			end
			i = get_from_table(tab, "SimPinTimes")
			if i then info.unlock_retries_left = i[1] end
			i = get_from_table(tab, "SimPukTimes")
			if i then info.unblock_retries_left = i[1] end
			return true
		end
	elseif error then
		log_error(error)
	end
	return nil, "Failed to get SIM info"
end

function Mapper:get_pin_info(device, info)
	info.pin_type = "pin1"
	local data, error = curl_get(device, string.format("http://%s/api/pin/status", device.web_info.ip))
	if data then
		local tab = lom.parse(data)
		if tab then
			local sim_state
			local i = get_from_table(tab, "SimState")
			if i then 
				if i[1] == "257" then sim_state = "ready"
				elseif i[1] == "260" then sim_state = "locked" end
			end
			i = get_from_table(tab, "PinOptState")
			if i then 
				if i[1] == "259" then info.pin_state = "enabled_verified"
				elseif i[1] == "261" then info.pin_state = "blocked"
				elseif i[1] == "258" and sim_state == "ready" then info.pin_state = "disabled"
				elseif i[1] == "258" and sim_state == "locked" then info.pin_state = "enabled_not_verified" end
			end
			i = get_from_table(tab, "SimPinTimes")
			if i then info.unlock_retries_left = tonumber(i[1]) end
			i = get_from_table(tab, "SimPukTimes")
			if i then info.unblock_retries_left = tonumber(i[1]) end
			return true
		end
	elseif error then
		log_error(error)
	end
	return nil, "Failed to get PIN info"
end

function Mapper:init_device(device, device_desc)
	if device.web_info.ip then
		device.web_info.uses_tokens = true
		runtime.log:info("Using gateway IP " .. device.web_info.ip)

		device.web_info.cookie_store = cURL.share_init()
		device.web_info.cookie_store:setopt_share("COOKIE")

		local retries = 5
		while retries > 0 do
			local tokens, error = get_tokens(device)
			-- Not all dongles use tokens
			if not tokens and error == "unavailable" then
				device.web_info.uses_tokens = false
				return true
			end
			if #tokens > 0 then
				device.web_info.tokens = tokens
				return true
			end
			helper.sleep(2)
			retries = retries - 1
		end
	end
	return nil
end

local function do_pin_command(device, oper, pin, newpin, puk)
	local c = string.format('<?xml version="1.0" encoding="UTF-8"?>' ..
		'<request>' ..
			'<OperateType>%d</OperateType>' ..
			'<CurrentPin>%s</CurrentPin>' ..
			'<NewPin>%s</NewPin>' ..
			'<PukCode>%s</PukCode>' ..
		'</request>', oper, pin, newpin, puk, "%s")

	local ret, error = curl_post(device, "http://%s/api/pin/operate", c)
	if not ret and error then
		log_error(error)
		if error == "108002" then
			add_error(device, "warning", "wrong_pin", "Wrong PIN")
		end
	end
	return ret, error
end

function Mapper:unlock_pin(device, pin_type, pin)
	return do_pin_command(device, 0, pin, "", "")
end

function Mapper:unblock_pin(device, pin_type, puk, newpin)
	return do_pin_command(device, 4, "", newpin, puk)
end

function Mapper:disable_pin(device, pin_type, pin)
	return do_pin_command(device, 2, pin, "", "")
end

function Mapper:enable_pin(device, pin_type, pin)
	return do_pin_command(device, 1, pin, "", "")
end

function Mapper:change_pin(device, pin_type, pin, newpin)
	return do_pin_command(device, 3, pin, newpin, "")
end

function Mapper:get_network_info(device, info)
	local data, error = curl_get(device, string.format("http://%s/api/net/current-plmn", device.web_info.ip))
	if data then
		local tab = lom.parse(data)
		if tab then
			local i = get_from_table(tab, "State")
			if i then 
				if i[1] == "0" then info.nas_state = "registered"
				else info.nas_state = "deregistered" end
			end
			info.plmn_info = {}
			i = get_from_table(tab, "FullName")
			if i then 
				info.plmn_info.description = i[1]
			end
			i = get_from_table(tab, "Numeric")
			if i and i[1] then 
				info.plmn_info.mcc = string.sub(i[1], 1, 3)
				info.plmn_info.mnc = string.sub(i[1], 4)
			end
			return true
		end
	elseif error then
		log_error(error)
	end
	return nil, "Failed to get network info"
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
		mode = "5"
	elseif selected_radio.type == "umts" then
		mode = "2"
	elseif selected_radio.type == "gsm" then
		mode = "1"
	end

	local roaming = 1
	if network_config.roaming == "none" then
		roaming = 0
	end

	local content = string.format('<?xml version="1.0" encoding="UTF-8"?>' ..
		'<response>' ..
			'<RoamAutoConnectEnable>%d</RoamAutoConnectEnable>' ..
			'<MaxIdelTime>0</MaxIdelTime>' ..
			'<ConnectMode>0</ConnectMode>' ..
			'<MTU>1340</MTU>' ..
			'<auto_dial_switch>0</auto_dial_switch>' ..
			'<pdp_always_on>0</pdp_always_on>' ..
		'</response>', roaming)
	curl_post(device, "http://%s/api/dialup/connection", content, 10)

	content = string.format('<?xml version="1.0" encoding="UTF-8"?>' ..
	'<request>' ..
		'<NetworkMode>%d</NetworkMode>' ..
		'<NetworkBand></NetworkBand>' ..
	'</request>', mode)

	return curl_post(device, "http://%s/api/net/network", content, 10)
end

function Mapper:get_radio_signal_info(device, info)
	local data, error = curl_get(device, string.format("http://%s/api/device/signal", device.web_info.ip))
	if data then
		local tab = lom.parse(data)
		if tab then
			local i = get_from_table(tab, "rssi")
			if i and i[1] then info.rssi = tonumber(string.match(i[1], "([0-9-]+)")) end
			i = get_from_table(tab, "rsrp")
			if i and i[1] then info.rsrp = tonumber(string.match(i[1], "([0-9-]+)")) end
			i = get_from_table(tab, "rsrq")
			if i and i[1] then info.rsrq = tonumber(string.match(i[1], "([0-9-]+)")) end
			i = get_from_table(tab, "sinr")
			if i and i[1] then info.snr = tonumber(string.match(i[1], "([0-9-]+)")) end
			i = get_from_table(tab, "ecio")
			if i and i[1] then info.ecio = tonumber(string.match(i[1], "([0-9-]+)")) end
			i = get_from_table(tab, "cell_id")
			if i and i[1] then device.buffer.network_info.cell_id = tonumber(i[1]) end
			i = get_from_table(tab, "pci")
			if i and i[1] then info.phy_cell_id = tonumber(i[1]) end
			return true
		end
	elseif error then
		log_error(error)
	end
	return nil, "Failed to get radio signal info"
end

local function get_profiles(device)
	local info = {
		profiles = {}
	}
	local data, error = curl_get(device, string.format("http://%s/api/dialup/profiles", device.web_info.ip))
	if data then
		local tab = lom.parse(data)
		if tab then
			local i = get_from_table(tab, "CurrentProfile")
			local currentProfile
			if i and i[1] then currentProfile = tonumber(i[1]) end
			if currentProfile then
				info.current_profile = currentProfile
				local profiles = get_from_table(tab, "Profiles")
				if profiles then
					for _, profile in pairs(profiles) do
						if profile.tag == "Profile" then
							local p = {}
							i = get_from_table(profile, "Name")
							if i and i[1] then
								p.name = i[1]
							end
							i = get_from_table(profile, "Index")
							if i and i[1] then
								p.id = tonumber(i[1])
							end
							i = get_from_table(profile, "ApnName")
							if i and i[1] then
								p.apn = i[1]
							end
							table.insert(info.profiles, p)
						end
					end
				end
			end
		end
	elseif error then
		log_error(error)
	end
	return info
end

function Mapper:get_session_info(device, info, session_id)
	local success = false
	local data, error = curl_get(device, string.format("http://%s/api/dialup/connection", device.web_info.ip))
	if data then
		local tab = lom.parse(data)
		if tab then
			info.proto = "router"
			info.router = {
				ipv4_addr = device.buffer.ip_info.ipv4_address,
				ipv4_gw = device.web_info.ip,
				ipv4_dns1 = device.buffer.ip_info.ipv4_dns1,
				ipv4_dns2 = device.buffer.ip_info.ipv4_dns2,
				ipv6_dns1 = device.buffer.ip_info.ipv6_dns1,
				ipv6_dns2 = device.buffer.ip_info.ipv6_dns2
			}
			local i = get_from_table(tab, "MaxIdelTime")
			if i and i[1] then info.router.idletime = tonumber(i[1]) end
			i = get_from_table(tab, "pdp_always_on")
			if i and i[1] then
				local pdp_always_on = tonumber(i[1])
				if pdp_always_on == 1 then
					info.router.always_on = true
				else
					info.router.always_on = false
				end
			end
			i = get_from_table(tab, "auto_dial_switch")
			if i and i[1] then
				local auto_dial_switch = tonumber(i[1])
				if auto_dial_switch == 1 then
					info.router.autoconnect = true
				else
					info.router.autoconnect = false
				end
			end
			success = true
		end
	elseif error then
		log_error(error)
	end
	if success then
		local profile_info = get_profiles(device)
		if profile_info.current_profile then
			for _, profile in pairs(profile_info.profiles) do
				if profile.id == profile_info.current_profile then
					info.apn = profile.apn
				end
			end
		end
		return true
	end
	return nil, "Failed to get session info"
end

function Mapper:start_data_session(device, session_id, profile)
	local content = '<?xml version="1.0" encoding="UTF-8"?>' ..
					'<request>' ..
						'<Action>1</Action>' ..
					'</request>'

	local ret, error = curl_post(device, "http://%s/api/dialup/dial", content)
	if not ret and error then
		log_error(error)
	end
end

function Mapper:stop_data_session(device, session_id)
	local content = '<?xml version="1.0" encoding="UTF-8"?>' ..
					'<request>' ..
						'<Action>0</Action>' ..
					'</request>'

	local ret, error = curl_post(device, "http://%s/api/dialup/dial", content)
	if not ret and error then
		log_error(error)
	end
end

function Mapper:periodic(device)
	if not device.state or not device.state.initialized then return nil end
	local data, error = curl_get(device, string.format("http://%s/api/monitoring/status", device.web_info.ip))
	if data then
		local tab = lom.parse(data)
		if tab then
			local i = get_from_table(tab, "ConnectionStatus")
			if i then
				if i[1] == "900" then device.buffer.session_info.session_state = "connecting"
				elseif i[1] == "901" then device.buffer.session_info.session_state = "connected"
				else device.buffer.session_info.session_state = "disconnected" end
			end
			i = get_from_table(tab, "WanIPAddress")
			if i then device.buffer.ip_info.ipv4_address = i[1] end
			i = get_from_table(tab, "WanIPv6Address")
			if i then device.buffer.ip_info.ipv6_address = i[1] end
			i = get_from_table(tab, "PrimaryDns")
			if i then device.buffer.ip_info.ipv4_dns1 = i[1] end
			i = get_from_table(tab, "SecondaryDns")
			if i then device.buffer.ip_info.ipv4_dns2 = i[1] end
			i = get_from_table(tab, "PrimaryIPv6Dns")
			if i then device.buffer.ip_info.ipv6_dns1 = i[1] end
			i = get_from_table(tab, "SecondaryIPv6Dns")
			if i then device.buffer.ip_info.ipv6_dns2 = i[1] end
			i = get_from_table(tab, "CurrentNetworkType")
			if i then
				i = tonumber(i[1])
				if i == 0 then device.buffer.radio_signal_info.radio_interface = "no_service"
				elseif i >= 1 and i <= 3 then device.buffer.radio_signal_info.radio_interface = "gsm"
				elseif i >= 4 and i <= 18 then device.buffer.radio_signal_info.radio_interface = "umts"
				elseif i == 19 then device.buffer.radio_signal_info.radio_interface = "lte" end
			end
			i = get_from_table(tab, "SignalIcon")
			if i then device.buffer.radio_signal_info.bars = tonumber(i[1]) end
		end
	elseif error then
		log_error(error)
	end
	return true
end

function Mapper:debug(device)
	if device.web_info.session_info.token then
		table.insert(device.debug.device_state, "Web API token: " .. device.web_info.tokens[1])
	end
	if device.web_info.session_info.expiration then
		table.insert(device.debug.device_state, "Device token expiration: " .. device.web_info.session_info.expiration)
	end
	return true
end

function Mapper:get_errors(device)
	return device.errors
end

function Mapper:network_scan(device, start)
	if start then
		device.scanresults = { scanning = true }
		local start_time = os.time()
		local content = '<?xml version="1.0" encoding="UTF-8"?>' ..
						'<request>' ..
							'<Action>0</Action>' ..
						'</request>'

		local data, error = curl_post(device, "http://%s/api/dialup/dial", content)
		if not data and error then
			log_error(error)
		end
		data, error = curl_get(device, string.format("http://%s/api/net/plmn-list", device.web_info.ip), 300)
		local duration = os.difftime(os.time(), start_time)
		local network_scan_list = {}
		if data then
			local tab = lom.parse(data)
			if tab then
				local networks = get_from_table(tab, "Networks")
				if networks then
					for _, network in pairs(networks) do
						if network.tag == "Network" then
							local entry = {
								plmn_info = {}
							}
							local i = get_from_table(network, "FullName")
							if i then 
								entry.plmn_info.description = i[1]
							end
							i = get_from_table(network, "State")
							if i then
								local state = tonumber(i[1])
								if state == 2 or state == 1 then
									entry.forbidden = false
								elseif state == 3 then
									entry.forbidden = true
								end
							end
							i = get_from_table(network, "Numeric")
							if i and i[1] then 
								entry.plmn_info.mcc = string.sub(i[1], 1, 3)
								entry.plmn_info.mnc = string.sub(i[1], 4)
							end
							i = get_from_table(network, "Rat")
							if i then
								local radio_interface = tonumber(i[1])

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
							table.insert(network_scan_list, entry)
						end
					end
				end
			end
			device.scanresults.duration = duration
			device.scanresults.network_scan_list = network_scan_list
			device.scanresults.scanning = false
		elseif error then
			log_error(error)
		end
	end
	if device.scanresults then
		return device.scanresults
	end
	return { scanning = false }
end

function Mapper:configure_device(device, config)
	if device.buffer.device_info and device.buffer.device_info.login_required then
		if config.device.username and config.device.password then
			device.runtime.log:info("Logging in to device using " .. config.device.username .. " " .. config.device.password)
			return login(device, config.device.username, config.device.password)
		end
	end
	return true
end

function Mapper:get_profile_info(device, info)
	local profile_info = get_profiles(device)
	info.profiles = profile_info.profiles
	return true
end

function M.create(rt, pid)
	runtime = rt

	local mapper = {
		mappings = {
			get_errors = "override"
		}
	}

	setmetatable(mapper, Mapper)
	return mapper
end

return M
