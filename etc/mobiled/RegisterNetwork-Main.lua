local M = {}

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
	"session_config_changed"
}

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	local device_config = mobiled.get_device_config(device)
	local session, profile = mobiled.get_attach_context(device)

	if not session or not session.activated then
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

	-- We need to configure the attach context
	mobiled.configure_attach_context(device, session, profile)

	local info = device:get_device_info()
	if info and info.power_mode ~= "online" then
		log:info("Bringing device online")
		device:set_power_mode("online")
	end

	if event.event == "timeout" or event.event == "network_deregistered" or event.event == "network_registered" then
		local sim_info = device:get_sim_info()
		if sim_info and sim_info.imsi then
			-- Verify if the current SIM card is allowed
			if not mobiled.validate_imsi(sim_info.imsi) then
				mobiled.add_error(device, "fatal", "invalid_sim", "Invalid IMSI")
				return "Error"
			end
		end
		info = device:get_network_info()
		if info then
			if info.nas_state == "registered" and (not info.service_state or info.service_state == "normal_service") then
				if type(info.plmn_info) == "table" then
					-- Verify if we are attached to the right network
					if not mobiled.validate_plmn(info.plmn_info.mcc, info.plmn_info.mnc) then
						log:info('PLMN "' .. info.plmn_info.mcc .. info.plmn_info.mnc .. '" not found in allowed operator list')
						log:info("Disabling device")
						runtime.config.set_device_enable(device, 0)
						mobiled.add_error(device, "fatal", "invalid_plmn", "Invalid PLMN selected")
						return "DeviceConfigure"
					end
					if sim_info and sim_info.imsi then
						-- Verify if international roaming is allowed
						if not mobiled.validate_roaming(sim_info.imsi, info.plmn_info.mcc, device_config.network.roaming) then
							log:info('International roaming is not allowed')
							log:info("Disabling device")
							runtime.config.set_device_enable(device, 0)
							mobiled.add_error(device, "fatal", "internationalroaming_not_allowed", "Internationalroaming not allowed")
							return "DeviceConfigure"
						end
					end
					return "DataSessionSetup"
				end
			else
				log:info("Attaching to network")
				if not device:network_attach() then
					log:warning("Failed to attach")
				end
			end
		end
	elseif event.event == "device_disconnected" then
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

	return "RegisterNetwork"
end

return M
