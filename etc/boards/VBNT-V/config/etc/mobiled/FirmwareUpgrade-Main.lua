local M = {}

M.SenseEventSet = {
	"platform_config_changed",
	"device_disconnected"
}

function M.check(runtime, event, dev_idx)
	if event.event == "platform_config_changed" then
		return "PlatformConfigure"
	end
	if event.event == "device_disconnected" then
		return "DeviceRemove"
	end
	return "FirmwareUpgrade"
end

return M
