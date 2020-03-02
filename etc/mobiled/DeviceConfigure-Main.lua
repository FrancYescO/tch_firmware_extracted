local M = {}

M.SenseEventSet = {
	"device_disconnected",
	"device_config_changed",
	"platform_config_changed"
}

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	if event.event == "device_disconnected" then
		return "DeviceRemove"
	elseif event.event == "platform_config_changed" then
		return "PlatformConfigure"
	end

	local config = mobiled.get_device_config(device)
	if not config or not config.device then
		log:error("No config found for device %d", device.sm.dev_idx)
		return "Error"
	end

	-- In case the device already auto-attached, we need to detach and configure the auto attach context
	mobiled.configure_attach_context(device, mobiled.get_attach_context(device))

	if not config.device.enabled then
		if not device:set_power_mode(config.device.disable_mode) then
			log:warning("Failed to disable device")
			return "DeviceConfigure"
		end
		return "Disabled"
	end
	if not device:configure(config) then
		log:warning("Failed to configure device")
		return "DeviceConfigure"
	end
	return "SimInit"
end

return M
