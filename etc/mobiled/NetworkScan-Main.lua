local M = {}

M.SenseEventSet = {
	"network_scan_start",
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

	local retState = "NetworkScan"

	device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	if event.event == "timeout" then
		result, errMsg = device:network_scan()
		if errMsg then log:error(errMsg) end
		if not result or result.scanning == false then
			retState = "RegisterNetwork"
		end
	elseif event.event == "network_scan_start" then
		device:network_scan(true)
	elseif (event.event == "device_config_changed") then
		retState = "DeviceConfigure"
	elseif (event.event == "platform_config_changed") then
		retState = "PlatformConfigure"
	elseif event.event == "device_disconnected" then
		retState = "DeviceRemove"
	elseif (event.event == "firmware_upgrade_start") then
		retState = "FirmwareUpgrade"
	elseif (event.event == "qualtest_start") then
		retState = "QualTest"
	end

	return retState
end

return M
