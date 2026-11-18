local M = {}

local helper = require('mobiled.scripthelpers')

function M.entry(runtime, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return false
	end

	local ret
	ret, errMsg = device:init()
	if not ret then
		if errMsg then log:error(errMsg) end
		if mobiled.platform then
			local power_control = mobiled.platform.get_linked_power_control(device)
			if power_control then
				if power_control.reset then
					log:error("Reset the device")
					power_control.reset()
				elseif power_control.power_on and power_control.power_off then
					log:error("Power-cycle the device")
					power_control.power_off()
					helper.sleep(0.5)
					power_control.power_on()
				end
			end
		end
		runtime.mobiled.remove_device(device)
		return false
	end

	return true
end

return M
