local M = {}

function M.exit(runtime, _, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return false
	end

	local state_data = device.sm:get_state_data()
	if state_data.measurement_timer then
		state_data.measurement_timer:cancel()
		state_data.measurement_timer = nil
	end

	return true
end

return M
