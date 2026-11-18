local M = {}

local pinType = "pin1"

M.SenseEventSet = {
	"pin_unlocked",
	"pin_unblocked",
	"pin_changed",
	"pin_enabled",
	"pin_disabled",
	"device_disconnected",
	"device_config_changed",
	"firmware_upgrade_start",
	"qualtest_start"
}

local helper = require('mobiled.scripthelpers')

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	if event.event == "timeout" or helper.startswith(event.event, "pin_") then
		local info = device:get_pin_info(pinType)
		if info then
			if info.pin_state == "disabled" or info.pin_state == "enabled_verified" then
				return "SelectAntenna"
			elseif info.pin_state == "permanently_blocked" then
				mobiled.add_error(device, "fatal", "invalid_sim", "SIM permanently blocked")
				return "Error"
			elseif info.pin_state == "enabled_not_verified" then
				if mobiled.unlock_pin_from_config(device, pinType) then
					return "SelectAntenna"
				end
			end
		end
	elseif event.event == "device_disconnected" then
		return "DeviceRemove"
	elseif event.event == "device_config_changed" then
		return "DeviceConfigure"
	elseif event.event == "firmware_upgrade_start" then
		return "FirmwareUpgrade"
	elseif event.event == "qualtest_start" then
		return "QualTest"
	end

	return "UnlockSim"
end

return M
