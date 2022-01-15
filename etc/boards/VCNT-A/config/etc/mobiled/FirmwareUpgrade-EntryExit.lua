local M = {}

local firmware_upgrade_timeout = 1800

function M.entry(runtime, dev_idx)
	local log = runtime.log
	local mobiled = runtime.mobiled

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return false
	end
	local info = device:get_device_info()
	if info.mode ~= "upgrade" then
		device:firmware_upgrade(device.info.firmware_upgrade.path)
		return false
	end

	local state_data = device.sm:get_state_data()
	log:info("Setting firmware upgrade timeout to %d seconds", firmware_upgrade_timeout)
	state_data.firmware_upgrade_timer = { value = firmware_upgrade_timeout, timer = runtime.uloop.timer(function()
		log:error("Timeout in FirmwareUpgrade after " .. state_data.firmware_upgrade_timer.value .. " seconds")
		state_data.firmware_upgrade_timer = nil
		device.info.firmware_upgrade.status = "timeout"
		runtime.events.send_event("mobiled", { event = "firmware_upgrade_failed", dev_idx = dev_idx })
	end, firmware_upgrade_timeout * 1000) }
	return true
end

return M
