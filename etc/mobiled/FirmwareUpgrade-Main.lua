local M = {}

M.SenseEventSet = {
	"device_disconnected",
	"firmware_upgrade_done",
	"firmware_upgrade_failed"
}

function M.check(runtime, event, dev_idx)
	local log = runtime.log
	local device, errMsg = runtime.mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	if event.event == "device_disconnected" then
		return "DeviceRemove"
	end

	local state_data = device.sm:get_state_data()
	if not state_data.firmware_upgrade_timer then
		return "DeviceInit"
	end

	local info = device:get_firmware_upgrade_info()
	if info and (info.status == "not_running" or info.status == "done" or info.status == "failed" or info.status == "no_upgrade_available") then
		local duration = state_data.firmware_upgrade_timer.value - state_data.firmware_upgrade_timer.timer:remaining()/1000
		state_data.firmware_upgrade_timer.timer:cancel()
		state_data.firmware_upgrade_timer = nil
		log:info(string.format('FirmwareUpgrade completed with status "%s" after %.1f seconds', info.status, duration))
		return "DeviceInit"
	end

	return "FirmwareUpgrade"
end

return M
