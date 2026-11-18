local M = {}

M.SenseEventSet = {
	"device_disconnected",
	"device_config_changed",
	"platform_config_changed",
	"firmware_upgrade_start",
	"sim_initialized",
	"qualtest_start"
}

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then runtime.log:error(errMsg) end
		return "DeviceRemove"
	end

	if event.event == "device_config_changed" then
		return "DeviceConfigure"
	elseif event.event == "platform_config_changed" then
		return "PlatformConfigure"
	elseif event.event == "device_disconnected" then
		return "DeviceRemove"
	elseif event.event == "firmware_upgrade_start" then
		return "FirmwareUpgrade"
	elseif event.event == "qualtest_start" then
		return "QualTest"
	elseif event.event == "sim_initialized" then
		runtime.log:notice("Enabling device due to SIM card initialization")
		runtime.config.set_device_enable(device, 1)
		return "DeviceConfigure"
	end

	return "Disabled"
end

return M
