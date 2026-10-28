---------------------------------
--! @file
--! @brief The main device functionality exposed to the state scripts
---------------------------------

local table, tostring = table, tostring
local helper = require("mobiled.scripthelpers")
local detector = require('mobiled.detector')
local runtime

local Device = {}
Device.__index = Device

function Device:get_stats()
	local uptime = helper.uptime()
	local stats = {
		uptime = uptime - self.stats.creation_uptime,
		network = self.stats.network,
		sim = self.stats.sim,
		interfaces = {},
		sessions = {}
	}
	for _, session in pairs(self.__sessions) do
		table.insert(stats.sessions, { session_id = session.session_id, disconnected = session.stats.disconnected, deactivated = session.stats.deactivated })
		if session.interface and runtime.mobiled.stats.interfaces[session.interface] then
			local ifstats = runtime.mobiled.stats.interfaces[session.interface]
			table.insert(stats.interfaces, { interface = session.interface, ifup = ifstats.ifup, ifdown = ifstats.ifdown, ['ifup-failed'] = ifstats['ifup-failed'], ifupdate = ifstats.ifupdate })
		end
	end
	return stats
end

function Device:get_info_from_cache(key, max_age, ...)
	if max_age then
		local cached_result = self.info.cache[key]
		if cached_result then
			local current_age = os.difftime(os.time(), cached_result.time)
			if current_age < max_age then
				runtime.log:debug("%s result from cache (%d seconds old, max_age %d)", key, current_age, max_age)
				return cached_result.info
			end
		end
	end
	runtime.log:debug("%s renew cache", key)
	local ret, errMsg = self.__plugin.plugin[key](self.__plugin_id, ...)
	if ret then
		self.info.cache[key] = { time = os.time(), info = ret }
	else
		self.info.cache[key] = nil
	end
	return ret, errMsg
end

--! @brief Initialize the device. This function will make sure the initialized value in the device_info table is set to true
--! @return true on success. nil and an error message on failure

function Device:init()
	return self.__plugin.plugin.init_device(self.__plugin_id)
end

--! @brief Configure the device. This function will make sure the radio and network selection parameters are set correctly
--! @return true on success. nil and an error message on failure

function Device:configure(params)
	local voice_interface = runtime.mobiled.platform.get_linked_voice_interface(self)
	if voice_interface then
		if not params.platform then
			params.platform = {}
		end
		params.platform.voice_interfaces = voice_interface.interfaces
	end
	return self.__plugin.plugin.configure_device(self.__plugin_id, params)
end

--! @brief Destroy any device specific allocations and break the link between plugin and device
--! @param force Will be set to true if the device is already disconnected
--! @return true on success. nil and an error message on failure

function Device:destroy(force)
	if not force then
		self:network_detach()
	end
	return self.__plugin.plugin.destroy_device(self.__plugin_id, force)
end

--! @brief Get IPv4 and IPv6 information
--! @param session_id The PDN for which you want to retrieve the information
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_ip_info(session_id)
	return self.__plugin.plugin.get_ip_info(self.__plugin_id, session_id)
end

--! @brief Get network time information
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_time_info()
	return self.__plugin.plugin.get_time_info(self.__plugin_id)
end

--! @brief Get device info like model and manufacturer
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_device_info()
	local info = self.__plugin.plugin.get_device_info(self.__plugin_id)
	if not info then return {} end

	info.dev_desc = self.desc
	if self.info and self.info.network_interfaces then
		local network_interface_names = {}
		for _, network_interface in ipairs(self.info.network_interfaces) do
			table.insert(network_interface_names, network_interface.name)
		end
		info.network_interfaces = table.concat(network_interface_names, " ")
	end
	if not info.device_config_parameter then
		info.device_config_parameter = self.info.device_config_parameter
	end
	if (info.cs_voice_support or info.volte_support) and not info.voice_interfaces then
		local voice_interfaces = runtime.mobiled.platform.get_linked_voice_interfaces(self)
		if voice_interfaces then
			info.voice_interfaces = voice_interfaces.interfaces
		end
	end

	if info.imei and info.imei_svn then
		info.imeisv = string.sub(info.imei, 1, 14) .. info.imei_svn
	end

	return info
end

--! @brief Get device statistics like uptime, number of disconnects
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_device_stats()
	local stats = self:get_stats()
	if self.__plugin.plugin.get_device_stats then
		helper.merge_tables(stats, self.__plugin.plugin.get_device_stats(self.__plugin_id) or {})
	end
	return stats
end

--! @brief Get device capabilities like band_selection_support
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_device_capabilities()
	return self.__plugin.plugin.get_device_capabilities(self.__plugin_id)
end

--! @brief Get network info like cell_id and nas_state
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_network_info(max_age)
	local info = self:get_info_from_cache("get_network_info", max_age)
	if info.cell_id and info.plmn_info and info.plmn_info.mcc and info.plmn_info.mnc then
		local cgi = string.format('%s%s%X', info.plmn_info.mcc, info.plmn_info.mnc, info.cell_id)
		if info.tracking_area_code then
			info.ecgi = cgi
		elseif info.location_area_code then
			info.cgi = cgi
		end
	end
	return info
end

local function get_ppp_session_info(info, session)
	if session.interface then
		local ret = helper.getUbusData(runtime.ubus, "network.interface." .. session.interface .. "_ppp", "status", {})
		if ret and ret.up == "true" then
			info.session_state = "connected"
		end
	end
end

--! @brief Get the supported PDP types from the device and compare against the preferred PDP type
--! @param The preferred PDP type
--! @return The preferred PDP type when supported. nil and an error message on failure

function Device:get_supported_pdp_type(pdp_type_pref)
	local info = self.__plugin.plugin.get_device_capabilities(self.__plugin_id)
	if info and info.supported_pdp_types then
		for _, pdp_type in pairs(info.supported_pdp_types) do
			if pdp_type == pdp_type_pref then
				return pdp_type_pref
			end
		end
		return nil, "Unsupported PDP type"
	end
	return pdp_type_pref
end

--! @brief Get session info like state, duration and packet counters
--! @param session_id The PDN for which you want to retrieve the information
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_session_info(session_id)
	local info, errMsg = self.__plugin.plugin.get_session_info(self.__plugin_id, session_id)
	if type(info) ~= "table" then return nil, errMsg end

	if not info.session_state then info.session_state = "disconnected" end
	if info.proto then
		if not info[info.proto] then info[info.proto] = {} end
		local ifname = self:get_network_interface(session_id)
		if ifname then
			info[info.proto].ifname = ifname
		end
		if info.proto == "ppp" then
			local session = self:get_data_session(session_id)
			if session and session.profile_id then
				local profile = runtime.mobiled.get_profile(self, session.profile_id)
				if profile then
					info.ppp.username = profile.username
					info.ppp.password = profile.password
					info.ppp.authentication = profile.authentication
					info.ppp.apn = profile.apn
					local supported_pdp_type = self:get_supported_pdp_type(profile.pdptype)
					if not supported_pdp_type then
						runtime.log:info("Unsupported PDP type requested. Falling back to IPv4")
						info.ppp.pdptype = "ipv4"
					else
						info.ppp.pdptype = supported_pdp_type
					end
					info.ppp.dial_string = profile.dial_string
				end
			end
			get_ppp_session_info(info, session)
		elseif info.proto == "dhcp" then
			local session = self:get_data_session(session_id)
			if session and session.profile_id then
				local profile = runtime.mobiled.get_profile(self, session.profile_id)
				if profile then
					local supported_pdp_type = self:get_supported_pdp_type(profile.pdptype)
					if not supported_pdp_type then
						runtime.log:info("Unsupported PDP type requested. Falling back to IPv4")
						info.dhcp.pdptype = "ipv4"
					else
						info.dhcp.pdptype = supported_pdp_type
					end
				end
			end
		end
		if info.session_state == "connected" then
			helper.merge_tables(info[info.proto], self:get_ip_info(session_id))
		end
	end

	return info
end

--! @brief Get profile info stored on device
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_profile_info()
	return self.__plugin.plugin.get_profile_info(self.__plugin_id)
end

--! @brief Get SIM info
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_sim_info()
	return self.__plugin.plugin.get_sim_info(self.__plugin_id)
end

--! @brief Get PIN info like pin_state and reties left
--! @param pin_type The PIN for which you want to request this info
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_pin_info(pin_type)
	return self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
end

--! @brief When start is set to true, starts a new network scan. Otherwise returns any previous scan results
--! @param start Whether to start a new network scan or not
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:network_scan(start)
	return self.__plugin.plugin.network_scan(self.__plugin_id, start)
end

--! @brief Send an SMS
--! @param number The number to send the SMS to
--! @param message The message to send
--! @return true on success. nil and an error message on failure

function Device:send_sms(number, message)
	return self.__plugin.plugin.send_sms(self.__plugin_id, number, message)
end

--! @brief Delete an SMS
--! @param message_id The ID of the SMS to delete
--! @return true on success. nil and an error message on failure

function Device:delete_sms(message_id)
	return self.__plugin.plugin.delete_sms(self.__plugin_id, message_id)
end

--! @brief Mark an SMS as read or unread
--! @param message_id The ID of the SMS to mark
--! @return true on success. nil and an error message on failure

function Device:set_sms_status(message_id, status)
	return self.__plugin.plugin.set_sms_status(self.__plugin_id, message_id, status)
end

--! @brief Retrieve info about the available SMS storage
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_sms_info()
	return self.__plugin.plugin.get_sms_info(self.__plugin_id)
end

--! @brief Retrieves the list of SMS messages on the device
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_sms_messages()
	return self.__plugin.plugin.get_sms_messages(self.__plugin_id)
end

--! @brief Set the power mode of the device to online or airplane
--! @param mode The mode to set the device to
--! @return true on success. nil and an error message on failure

function Device:set_power_mode(mode)
	return self.__plugin.plugin.set_power_mode(self.__plugin_id, mode)
end

--! @brief Called periodically by informer.lua
--! @return true on success. nil and an error message on failure

function Device:periodic()
	return self.__plugin.plugin.periodic(self.__plugin_id)
end

--! @brief Unlock the SIM with the given PIN
--! @param pin_type Which pin to unlock
--! @param pin The PIN to use
--! @return true on success. nil and an error message on failure

function Device:unlock_pin(pin_type, pin)
	local info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
	local oldUnlockRetries = info.unlock_retries_left
	local ret, errMsg = self.__plugin.plugin.unlock_pin(self.__plugin_id, pin_type, pin)
	if not ret then
		return ret, errMsg
	end
	info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
	local newUnlockRetries = info.unlock_retries_left
	if newUnlockRetries and oldUnlockRetries and (newUnlockRetries < oldUnlockRetries) then
		return nil, "Invalid PIN code provided"
	end
	return true
end

--! @brief Change the PIN code to the given PIN
--! @param pin_type Which pin to unlock
--! @param oldPin The current PIN
--! @param newPin The new PIN to use
--! @return true on success. nil and an error message on failure

function Device:change_pin(pin_type, oldPin, newPin)
	local info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
	local oldUnlockRetries = info.unlock_retries_left
	local ret, errMsg = self.__plugin.plugin.change_pin(self.__plugin_id, pin_type, oldPin, newPin)
	if not ret then
		return ret, errMsg
	end
	info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
	local newUnlockRetries = info.unlock_retries_left
	if newUnlockRetries and oldUnlockRetries and (newUnlockRetries < oldUnlockRetries) then
		return nil, "Invalid PIN code provided"
	end
	return true
end

function Device:__enable_pin(pin_type, pin, enable)
	local info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
	local oldUnlockRetries = info.unlock_retries_left
	local ret, errMsg
	if(enable) then
		ret, errMsg = self.__plugin.plugin.enable_pin(self.__plugin_id, pin_type, pin)
	else
		ret, errMsg = self.__plugin.plugin.disable_pin(self.__plugin_id, pin_type, pin)
	end
	if not ret then
		return ret, errMsg
	end
	info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
	local newUnlockRetries = info.unlock_retries_left
	if newUnlockRetries and oldUnlockRetries and (newUnlockRetries < oldUnlockRetries) then
		return nil, "Invalid PIN code provided"
	end
	return true
end

--! @brief Enable PIN protection
--! @param pin_type Which pin to unlock
--! @param pin The current PIN
--! @return true on success. nil and an error message on failure

function Device:enable_pin(pin_type, pin)
	return self:__enable_pin(pin_type, pin ,true)
end

--! @brief Disable PIN protection
--! @param pin_type Which pin to unlock
--! @param pin The current PIN
--! @return true on success. nil and an error message on failure

function Device:disable_pin(pin_type, pin)
	return self:__enable_pin(pin_type, pin ,false)
end

--! @brief Unblock the SIM using the given PUK
--! @param pin_type Which pin to unlock
--! @param puk The PUK
--! @param newPin The new PIN to use
--! @return true on success. nil and an error message on failure

function Device:unblock_pin(pin_type, puk, newPin)
	local info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
	local oldUnblockRetries = info.unblock_retries_left
	local ret, errMsg = self.__plugin.plugin.unblock_pin(self.__plugin_id, pin_type, puk, newPin)
	if not ret then
		return ret, errMsg
	end
	info = self.__plugin.plugin.get_pin_info(self.__plugin_id, pin_type)
	local newUnblockRetries = info.unblock_retries_left
	if newUnblockRetries and oldUnblockRetries and (newUnblockRetries < oldUnblockRetries) then
		return nil, "Invalid PUK code provided"
	end
	return true
end

--! @brief Starts a new PDN connectivity request
--! @param session_id Which PDN to activate
--! @param profile A table containing info like APN, PDP type, username and password
--! @param internal Indicates to the device the PDN will not be used by the host
--! @return true on success. nil and an error message on failure

function Device:start_data_session(session_id, profile, internal)
	return self.__plugin.plugin.start_data_session(self.__plugin_id, session_id, profile, internal)
end

--! @brief Stops PDN connectivity
--! @param session_id Which PDN to deactivate
--! @return true on success. nil and an error message on failure

function Device:stop_data_session(session_id)
	return self.__plugin.plugin.stop_data_session(self.__plugin_id, session_id)
end

--! @brief Attach to the network
--! @return true on success. nil and an error message on failure

function Device:network_attach()
	return self.__plugin.plugin.network_attach(self.__plugin_id)
end

--! @brief Detach from the network
--! @return true on success. nil and an error message on failure

function Device:network_detach()
	return self.__plugin.plugin.network_detach(self.__plugin_id)
end

--! @brief Get radio info like rssi, rsrp and rsrq
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_radio_signal_info(max_age)
	return self:get_info_from_cache("get_radio_signal_info", max_age)
end

--! @brief Creates the default attach profile. Some modules require doing this before they register to the network
--! @param profile A table containing info like APN, PDP type, username and password
--! @return true on success. nil and an error message on failure

function Device:set_attach_params(profile)
	return self.__plugin.plugin.set_attach_params(self.__plugin_id, profile)
end

--! @brief Functionality depends on the plugin
--! @return true on success. nil and an error message on failure

function Device:debug()
	return self.__plugin.plugin.debug(self.__plugin_id)
end

--! @brief Upgrades the device firmware using the given path
--! @param path The path where the firmware image can be found
--! @return true on success. nil and an error message on failure

function Device:firmware_upgrade(path)
	return self.__plugin.plugin.firmware_upgrade(self.__plugin_id, path)
end

--! @brief Get firmware upgrade info like status
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_firmware_upgrade_info()
	return self.__plugin.plugin.get_firmware_upgrade_info(self.__plugin_id)
end

local function update_not_nil(session, session_config, params)
	for _, param in pairs(params) do
		if session_config[param] ~= nil then
			session[param] = session_config[param]
		end
	end
end

--! @brief Adds a PDN on a given device
--! @param session_config table containing session_id, profile_id, optional parameter and interface
--! @return session context on success. nil and an error message on failure

function Device:add_data_session(session_config)
	local session = self.__sessions[session_config.session_id]
	if not session then
		session = {
			session_id = session_config.session_id,
			profile_id = session_config.profile_id,
			interface = session_config.interface,
			internal = session_config.internal or false,
			optional = session_config.optional or false,
			autoconnect = session_config.autoconnect or false,
			bridge = session_config.bridge,
			name = session_config.name or "internet",
			activated = session_config.activated or false,
			allowed = true,
			pdn_retry_timer = { default_value = session_config.pdn_retry_timer_value or runtime.config.get_config().pdn_retry_timer_value },
			stats = {
				disconnected = 0,
				deactivated = 0
			}
		}
		if not session.internal then
			session.changed = true
		end
		self.__sessions[session_config.session_id] = session
	else
		if session_config.profile_id and session_config.profile_id ~= session.profile_id then
			local info = self:get_session_info(session.session_id)
			if info.session_state == "connected" then
				return nil, "Not allowed to make changes. Disconnect data session first"
			else
				session.changed = true
			end
			session.profile_id = session_config.profile_id
		end
		update_not_nil(session, session_config, {"autoconnect", "internal", "interface", "bridge", "pdn_retry_timer_value", "optional", "name"})
	end
	if self.__plugin.plugin.add_data_session then
		self.__plugin.plugin.add_data_session(self.__plugin_id, session_config)
	end
	return session
end

--! @brief Activate a PDN on a given device
--! @param session_id The ID of the data session to stop
--! @return true on success. nil and an error message on failure

function Device:deactivate_data_session(session_id)
	if session_id and self.__sessions[session_id] then
		self.__sessions[session_id].activated = false
		return true
	end
	return nil, "No such data session"
end

function Device:get_data_session(session_id)
	if session_id and self.__sessions[session_id] then
		return self.__sessions[session_id]
	end
	return nil, "Failed to get info for data session " .. tostring(session_id)
end

function Device:get_data_sessions()
	return self.__sessions
end

--! @brief Get the name of the plugin which is used by the device
--! @return The name of the plugin

function Device:get_plugin_name()
	if self.__plugin then return self.__plugin.name end
	return nil
end

--! @brief Get the corresponding network interface for a given data session
--! @param session_id The data session to get the network interface for
--! @return The name of the network interface or nil when not found
function Device:get_network_interface(session_id)
	if self.__plugin.plugin.get_network_interface then
		local ifname = self.__plugin.plugin.get_network_interface(self.__plugin_id, session_id)
		if ifname then
			return ifname
		end
	end
	if self.info and self.info.network_interfaces and self.info.network_interfaces[session_id+1] then
		return self.info.network_interfaces[session_id+1].name
	end
	return nil
end

--! @brief Execute a qualification test command
--! @param command The qualification test command to be executed
--! @return true on success. nil and an error message on failure

function Device:execute_command(command)
	if self.__plugin.plugin.execute_command then
		local status = runtime.mobiled.get_state(self.sm.dev_idx)
		local active

		if status == "QualTest" then
			active = "IN"
		else
			active = "NOT IN"
		end
		runtime.log:info("Execute command while " .. active .. " Qualification Test mode: '" .. command .. "'")
		local ret, err = self.__plugin.plugin.execute_command(self.__plugin_id, command)
		runtime.log:info("Execute command " .. command .. " returned.")
		return ret, err
	end
	return nil, "Not supported"
end

--! @brief Establish a voice call to a given number
--! @param number The number to call
--! @return true on success. nil and an error message on failure

function Device:dial(number)
	if self.__plugin.plugin.dial then
		return self.__plugin.plugin.dial(self.__plugin_id, number)
	end
	return nil, "Not supported"
end

--! @brief Stop a voice call with a given call_id
--! @param call_id The call to stop
--! @return true on success. nil and an error message on failure

function Device:end_call(call_id)
	if self.__plugin.plugin.end_call then
		return self.__plugin.plugin.end_call(self.__plugin_id, call_id)
	end
	return nil, "Not supported"
end

--! @brief Answer a voice call with a given call_id
--! @param call_id The call to answer
--! @return true on success. nil and an error message on failure

function Device:accept_call(call_id)
	if self.__plugin.plugin.accept_call then
		return self.__plugin.plugin.accept_call(self.__plugin_id, call_id)
	end
	return nil, "Not supported"
end

--! @brief Get info about a call with call_id
--! @param call_id The call to get info from
--! @return true on success. nil and an error message on failure

function Device:call_info(call_id)
	if self.__plugin.plugin.call_info then
		return self.__plugin.plugin.call_info(self.__plugin_id, call_id)
	end
	return nil, "Not supported"
end

--! @brief Multi party call actions
--! @param call_id The call to apply the action to
--! @param action The action to execute
--! @param second_call_id The optional second call to apply the action to
--! @return true on success. nil and an error message on failure

function Device:multi_call(call_id, action, second_call_id)
	if self.__plugin.plugin.multi_call then
		return self.__plugin.plugin.multi_call(self.__plugin_id, call_id, action, second_call_id)
	end
	return nil, "Not supported"
end

--! @brief Supplementary services actions
--! @param service Which service to use
--! @param action The action to execute
--! @param forwarding_type Optional, call forwarding type
--! @param forwarding_number Optional, call forwarding number
--! @return true on success. nil and an error message on failure

function Device:supplementary_service(service, action, forwarding_type, forwarding_number)
	if self.__plugin.plugin.supplementary_service then
		return self.__plugin.plugin.supplementary_service(self.__plugin_id, service, action, forwarding_type, forwarding_number)
	end
	return nil, "Not supported"
end

--! @brief Send DTMF tones
--! @param tones A string of ASCII characters representing the DTMF tones to send
--! @param interval Optional, The time to wait between sending DTMF tones in 1/10ths of a second
--! @param duration Optional, The duration of each tone in 1/10ths of a second
--! @return true on success. nil and an error message on failure

function Device:send_dtmf(tones, interval, duration)
	if self.__plugin.plugin.send_dtmf then
		return self.__plugin.plugin.send_dtmf(self.__plugin_id, tones, interval, duration)
	end
	return nil, "Not supported"
end

--! @brief Get a list of errors from the device
--! @return a list of errors

function Device:get_errors()
	if self.__plugin.plugin.get_errors then
		return self.__plugin.plugin.get_errors(self.__plugin_id) or {}
	end
	return {}
end

--! @brief Clear the list of errors from the device
--! @return true on success. nil and an error message on failure

function Device:flush_errors()
	if self.__plugin.plugin.flush_errors then
		return self.__plugin.plugin.flush_errors(self.__plugin_id)
	end
	return nil, "Not supported"
end

--! @brief Retrieve IMS info
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_voice_info()
	if self.__plugin.plugin.get_voice_info then
		return self.__plugin.plugin.get_voice_info(self.__plugin_id)
	end
	return nil, "Not supported"
end

--! @brief Retrieve IMS capabilities
--! @return A table containing the requested info on success. nil and an error message on failure

function Device:get_voice_network_capabilities()
	if self.__plugin.plugin.get_voice_network_capabilities then
		return self.__plugin.plugin.get_voice_network_capabilities(self.__plugin_id)
	end
	return nil, "Not supported"
end

--! @brief Converts an existing call to a data (e.g. fax) call
--! @param call_id The call to convert
--! @param codec The desired codec (e.g., "PCMA", "PCMU", ...) or nil to use the codec that is specified in the configuration
--! @return true on success. nil and an error message on failure

function Device:convert_to_data_call(call_id, codec)
	if self.__plugin.plugin.convert_to_data_call then
		return self.__plugin.plugin.convert_to_data_call(self.__plugin_id, call_id, codec)
	end
	return nil, "Not supported"
end

--! @brief Configures the emergency numbers
--! @param numbers An array containing the emergency numbers
--! @return true on success. nil and an error message on failure

function Device:set_emergency_numbers(numbers)
	if self.__plugin.plugin.set_emergency_numbers then
		return self.__plugin.plugin.set_emergency_numbers(self.__plugin_id, numbers)
	end
	return nil, "Not supported"
end

local M = {}

function M.create(rt, params, plugin)
	runtime = rt

	local platform_network_interfaces = runtime.mobiled.platform.get_linked_network_interfaces({desc = params.dev_desc})
	if platform_network_interfaces then
		for _, network_interface in ipairs(platform_network_interfaces.interfaces or {}) do
			table.insert(params.network_interfaces, network_interface)
		end
	end

	local device = {
		__sessions = {},
		desc = params.dev_desc,
		type = params.dev_type,
		__plugin = plugin,
		info = {
			network_interfaces = params.network_interfaces,
			firmware_upgrade = {
				status = "not_running"
			},
			wifi_coexistence = {},
			cache = {}
		},
		errors = {},
		attach_retry_timer = {
			value = runtime.config.get_config().attach_retry_timer_value,
			attach_retry_count = runtime.config.get_config().attach_retry_count,
			attach_retries = 0
		},
		stats = {
			creation_uptime = helper.uptime(),
			network = {
				tracking_area_code_changed = 0,
				location_area_code_changed = 0,
				radio_interface_changed = 0,
				deregistered = 0,
				ecgi_changed = 0,
				cgi_changed = 0
			},
			sim = {
				removed = 0
			}
		}
	}

	local id, errMsg = device.__plugin.plugin.add_device(params)
	if not id then return nil, errMsg end
	--[[
		The ID assigned here is used internally in the plugin to identifty the device
		for cases where multiple devices use the same plugin
	]]--
	device.__plugin_id = id
	setmetatable(device, Device)

	helper.merge_tables(device.info, detector.info(device))

	return device
end

return M
