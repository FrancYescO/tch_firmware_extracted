local M = {}

M.SenseEventSet = {
	"device_disconnected",
	"sim_initialized",
	"sim_removed",
	"firmware_upgrade_start"
}

function M.check(runtime, event, dev_idx)
	if event.event == "device_disconnected" then
		return "DeviceRemove"
	elseif event.event == "sim_initialized" or event.event == "sim_removed" then
		return "SimInit"
	elseif event.event == "firmware_upgrade_start" then
		return "FirmwareUpgrade"
	end
	return "Error"
end

return M
