local error_handler = require("mobiled.error")

local M = {}

local valid_pdn_retry_causes = {
	[8] = true,
	[26] = true,
	[27] = true,
	[28] = true,
	[29] = true,
	[30] = true,
	[31] = true,
	[32] = true,
	[33] = true,
	[34] = true,
	[38] = true
}

M.SenseEventSet = {
	"network_scan_start",
	"network_deregistered",
	"network_registered",
	"device_disconnected",
	"device_config_changed",
	"platform_config_changed",
	"firmware_upgrade_start",
	"qualtest_start",
	"antenna_change_detected",
	"sim_removed",
	"session_config_changed",
	"sim_acl_changed",
	"attach_retry_timer_expired"
}

local function disable_device(runtime, device)
	runtime.log:warning("Disabling device")
	runtime.config.set_device_enable(device, 0)
	return "DeviceConfigure"
end

local function start_attach_retry_timer(runtime, device)
	runtime.log:info("Starting attach retry timer")
	device.attach_retry_timer.timer = runtime.uloop.timer(function()
		device.attach_retry_timer.timer = nil
		runtime.log:info("Attach retry timer expired")
		runtime.events.send_event("mobiled", { event = "attach_retry_timer_expired", dev_idx = device.sm.dev_idx })
	end, device.attach_retry_timer.value * 1000)
end

function M.check(runtime, event, dev_idx)
	if event.event == "device_disconnected" then
		return "DeviceRemove"
	elseif event.event == "network_scan_start" then
		return "NetworkScan"
	elseif event.event == "device_config_changed" then
		return "DeviceConfigure"
	elseif event.event == "platform_config_changed" then
		return "PlatformConfigure"
	elseif event.event == "firmware_upgrade_start" then
		return "FirmwareUpgrade"
	elseif event.event == "qualtest_start" then
		return "QualTest"
	elseif event.event == "antenna_change_detected" then
		return "SelectAntenna"
	elseif event.event == "sim_removed" then
		return "SimInit"
	end

	local mobiled = runtime.mobiled
	local log = runtime.log

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	local sim_info = device:get_sim_info()
	if not sim_info then
		return "RegisterNetwork"
	end
	if sim_info.sim_state ~= "ready" then
		return "SimInit"
	end

	local device_config = mobiled.get_device_config(device)
	local session, profile = mobiled.get_attach_context(device)

	if not profile then
		log:error("Failed to retrieve attach profile")
		return "RegisterNetwork"
	end

	if not mobiled.apn_is_allowed(device, profile.apn) then
		session.allowed = false
	else
		session.allowed = true
	end

	if not session or not session.activated or not session.allowed then
		if session and not session.allowed then
			mobiled.add_error(device, "fatal", "invalid_apn", "APN not allowed by SIM access control list")
		end
		if device_config.device.detach_mode == "detach" then
			log:info("Detaching from network")
			if not device:network_detach() then
				log:warning("Failed to detach")
			end
			return "Idle"
		elseif device_config.device.detach_mode == "poweroff" then
			log:info("Turning the radio off")
			if not device:set_power_mode(device_config.device.disable_mode) then
				log:warning("Failed to turn off the radio")
			end
			return "Idle"
		end
	end

	if session and session.changed and device.attach_retry_timer.timer then
		device.attach_retry_timer.timer:cancel()
		device.attach_retry_timer.timer = nil
		log:info("Canceled attach retry timer")
	end

	if not mobiled.configure_attach_context(device, session, profile) then
		log:warning("Failed to configure attach context")
		return "RegisterNetwork"
	end

	local rf_control = mobiled.platform.get_linked_rf_control(device)
	if rf_control and rf_control.enable then
		rf_control.enable()
	end

	local info = device:get_device_info()
	if info and info.power_mode ~= "online" then
		log:info("Bringing device online")
		if not device:set_power_mode("online") then
			return "RegisterNetwork"
		end
	end

	if event.event == "network_deregistered" and event.reject_cause and not device.attach_retry_timer.timer then
		local cause = tonumber(event.reject_cause)
		log:warning(string.format('Attach failed with error "%s"', error_handler.get_error_cause(cause) or "Unknown"))
		if cause and valid_pdn_retry_causes[cause] then
			start_attach_retry_timer(runtime, device)
			return "RegisterNetwork"
		end
	end

	-- Verify if the current SIM card is allowed
	if sim_info.imsi and not mobiled.validate_imsi(sim_info.imsi) then
		log:warning('Invalid IMSI')
		mobiled.add_error(device, "fatal", "invalid_sim", "Invalid IMSI")
		return disable_device(runtime, device)
	end

	local network_info = device:get_network_info()
	if not network_info then
		return "RegisterNetwork"
	end

	if network_info.nas_state == "registered" and (not network_info.service_state or network_info.service_state == "normal_service") then
		if type(network_info.plmn_info) == "table" then
			-- Verify if we are attached to the right network
			if not mobiled.validate_plmn(network_info.plmn_info.mcc, network_info.plmn_info.mnc) then
				log:warning('PLMN "%s%s" not found in allowed operators', network_info.plmn_info.mcc, network_info.plmn_info.mnc)
				mobiled.add_error(device, "fatal", "invalid_plmn", "Invalid PLMN selected")
				return disable_device(runtime, device)
			end
			if sim_info.imsi then
				-- Verify if roaming is allowed
				if not mobiled.validate_roaming(sim_info.imsi, network_info.plmn_info.mcc, network_info.plmn_info.mnc, device_config.network.roaming) then
					log:warning('Roaming is not allowed')
					mobiled.add_error(device, "fatal", "roaming_not_allowed", "Roaming is not allowed")
					return disable_device(runtime, device)
				end
			end
			return "DataSessionSetup"
		end
	elseif not device.attach_retry_timer.timer then
		if device.attach_retry_timer.attach_retries > device.attach_retry_timer.attach_retry_count then
			start_attach_retry_timer(runtime, device)
			device.attach_retry_timer.attach_retries = 0
			return "RegisterNetwork"
		end
		log:info("Attaching to network")
		device:network_attach()
		device.attach_retry_timer.attach_retries = device.attach_retry_timer.attach_retries + 1
	else
		log:info("Not allowed to attach")
	end

	return "RegisterNetwork"
end

return M
