local M = {}

M.SenseEventSet = {
	"device_disconnected",
	"device_config_changed",
	"platform_config_changed",
	"firmware_upgrade_start",
	"qualtest_start"
}

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log
	local errMsg, device, result

	device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	if event.event == "timeout" then
		result, errMsg = device:network_scan()
		if errMsg then log:error(errMsg) end
		if not result or result.scanning == false then
			return "RegisterNetwork"
		end
	elseif event.event == "device_config_changed" then
		return "DeviceConfigure"
	elseif event.event == "platform_config_changed" then
		return "PlatformConfigure"
	elseif event.event == "device_disconnected" then
		return "DeviceRemove"
	elseif event.event == "firmware_upgrade_start" then
		return "FirmwareUpgrade"
	elseif event.event == "qualtest_start" then
		return "QualTest"
	end

	return "NetworkScan"
end

return M
