local M = {}

function M.entry(runtime, dev_idx)
	local mobiled = runtime.mobiled
	local log = runtime.log

	log:notice("NetworkScan-> Entry Function")

	local device, errMsg = mobiled.get_device(dev_idx)
	if not device then
		return false, errMsg
	end

	mobiled.stop_all_data_sessions(device)
	mobiled.propagate_session_state(device, "disconnected", "ipv4v6", device:get_data_sessions())

	if not device:network_detach() then
		log:warning("Failed to detach")
	end

	device:network_scan(true)

	return true
end

function M.exit(runtime, transition, dev_idx)
	local log = runtime.log
	log:notice("NetworkScan-> Exit Function")
	return true
end

return M
