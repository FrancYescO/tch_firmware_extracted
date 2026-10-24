local M = {}

function M.entry(runtime, dev_idx)
	runtime.log:notice("SelectAntenna-> Entry Function")
	return true
end

function M.exit(runtime, transition, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	log:notice("SelectAntenna-> Exit Function")

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
