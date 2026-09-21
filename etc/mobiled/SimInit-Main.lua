local M = {}

M.SenseEventSet = {
	"sim_removed",
	"sim_initialized",
	"device_disconnected",
	"device_config_changed",
	"firmware_upgrade_start",
	"platform_config_changed",
	"qualtest_start"
}

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	if event.event == "timeout" or event.event == "sim_initialized" then
		local info = device:get_sim_info()
		if info then
			local state_data = device.sm:get_state_data()
			-- We will try to retrieve the ICCID three times
			-- If it fails after that, we set the device ICCID param to "unknown"
			state_data.tries = state_data.tries or 0
			if not info.iccid then
				state_data.tries = state_data.tries + 1
				if state_data.tries < 3 then
					return "SimInit"
				end
				log:warning("Failed to retrieve ICCID")
				device.iccid = "unknown"
			else
				device.iccid = info.iccid
			end
			if info.sim_state == "locked" or info.sim_state == "blocked" or info.sim_state == "ready" then
				runtime.events.send_event("mobiled", { event = "sim_ready", dev_idx = device.sm.dev_idx })
				return "UnlockSim"
			end
		end
	elseif event.event == "device_disconnected" then
		return "DeviceRemove"
	elseif event.event == "device_config_changed" then
		return "DeviceConfigure"
	elseif event.event == "firmware_upgrade_start" then
		return "FirmwareUpgrade"
	elseif event.event == "platform_config_changed" then
		return "PlatformConfigure"
	elseif event.event == "qualtest_start" then
		return "QualTest"
	end

	return "SimInit"
end

return M
