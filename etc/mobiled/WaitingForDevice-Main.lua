local M = {}
local detector = require('mobiled.detector')
local helper = require('mobiled.scripthelpers')

M.SenseEventSet = {
	"device_connected",
	"platform_config_changed"
}

function M.check(runtime, event, dev_idx)
	local log = runtime.log
	local retState = "WaitingForDevice"

	if event.event == "timeout" or event.event == "device_connected" then
		-- In some cases this is run before the sysfs entries are created
		if event.event == "device_connected" then
			helper.sleep(2)
		end
		local dev, msg = detector.scan(runtime)
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
