local M = {}

function M.entry(runtime, dev_idx)
	runtime.log:notice("DataSessionSetup-> Entry Function")
	return true
end

-- Reset the PDN retry timer(s) when leaving the DataSessionSetup state
function M.exit(runtime, transition, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	log:notice("DataSessionSetup-> Exit Function")

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		if errMsg then log:error(errMsg) end
		return false
	end

	for _, session in pairs(device:get_data_sessions()) do
		if session.pdn_retry_timer.timer then
			session.pdn_retry_timer.timer:cancel()
			session.pdn_retry_timer.timer = nil
		end
		session.pdn_retry_timer.value = nil
	end

	return true
end

return M
