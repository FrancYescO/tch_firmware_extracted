local M = {}

function M.entry(runtime, dev_idx)
	runtime.log:notice("RegisterNetwork-> Entry Function")
	return true
end

-- Reset the attach retry timer when leaving the RegisterNetwork state
function M.exit(runtime, transition, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	log:notice("RegisterNetwork-> Exit Function")

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return false
	end

	if device.attach_retry_timer.timer then
		log:info("Canceled attach retry timer")
		device.attach_retry_timer.timer:cancel()
		device.attach_retry_timer.timer = nil
	end

	return true
end

return M
