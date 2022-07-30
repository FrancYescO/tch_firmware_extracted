local M = {}

M.SenseEventSet = {
	"device_connected",
	"platform_config_changed"
}

function M.check(runtime, event, dev_idx)
	local log = runtime.log
	local retState = "WaitingForDevice"

	if event.event == "timeout" or event.event == "device_connected" then
		local dev, msg = runtime.mobiled.add_device(dev_idx)
		if dev then
			retState = "DeviceInit"
		else
			if msg then log:error("Failed to add device (" .. msg .. ")") end
		end
	elseif event.event == "platform_config_changed" then
		return "PlatformConfigure"
	end

	return retState
end

return M
