local M = {}

M.SenseEventSet = {
	"device_disconnected",
	"platform_config_changed"
}

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled

	if event.event == "device_disconnected" then
		return "DeviceRemove"
	end

	local config = mobiled.get_config()
	if config and config.platform then
		if config.platform.power_on then
			mobiled.platform.power_all_on()
		else
			mobiled.platform.power_all_off()
			return "DeviceRemove"
		end
	end

	local device = mobiled.get_device(dev_idx)
	if not device then
		return "WaitingForDevice"
	end

	local info = device:get_device_info()
	if info and info.initialized then
		return "DeviceConfigure"
	end
	return "DeviceInit"
end

return M
