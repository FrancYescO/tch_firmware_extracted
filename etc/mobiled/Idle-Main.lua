local M = {}

M.SenseEventSet = {
	"network_scan_start",
	"network_deregistered",
	"session_disconnected",
	"session_connected",
	"session_teardown",
	"session_setup",
	"device_disconnected",
	"session_config_changed",
	"device_config_changed",
	"platform_config_changed",
	"firmware_upgrade_start",
	"pco_update_received",
	"qualtest_start",
	"antenna_change_detected",
	"sim_removed",
	"sim_acl_changed",
	"operator_config_changed"
}

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	if event.event == "timeout" or event.event == "network_deregistered" or event.event == "session_disconnected" then
		-- Verify if everything is still in the state we left it
		for _, session in pairs(device:get_data_sessions()) do
			local profile = mobiled.get_profile(device, session.profile_id)
			if not profile then
				log:error("Failed to retrieve profile")
				return "Idle"
			end

			if not mobiled.apn_is_allowed(device, profile.apn) then
				session.allowed = false
			else
				session.allowed = true
			end

			if session.session_id == 0 then
				local info = device:get_network_info()
				if info and info.nas_state ~= "registered" and session.activated and session.allowed then
					return "RegisterNetwork"
				end
			end

			local info = device:get_session_info(session.session_id)
			if info and (info.session_state ~= "connected" and not session.optional and not session.autoconnect and session.activated and session.allowed) or
						(info.session_state ~= "disconnected" and (not session.activated or not session.allowed)) then
				return "DataSessionSetup"
			end
		end
	elseif event.event == "session_connected" or
			event.event == "session_teardown" or
			event.event == "session_setup" or
			event.event == "session_config_changed" or
			event.event == "sim_acl_changed" then
		return "DataSessionSetup"
	elseif event.event == "device_disconnected" then
		return "DeviceRemove"
	elseif event.event == "pco_update_received" then
		return "DataSessionSetup"
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
	elseif event.event == "operator_config_changed" then
		log:notice("operator_config_changed received in Idle state... stopping all data sessions")
		mobiled.stop_all_data_sessions(device)
		return "RegisterNetwork"
	end

	return "Idle"
end

return M
