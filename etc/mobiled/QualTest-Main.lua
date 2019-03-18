local M = {}

M.SenseEventSet = {
	"qualtest_stop"
}

function M.check(runtime, event, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log
	local retState = "QualTest"

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return "DeviceRemove"
	end

	if event.event == "qualtest_stop" then
		retState = "DeviceInit"
	end

	return retState
end

return M
