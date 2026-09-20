local M = {}

function M.entry(runtime, dev_idx)
	runtime.log:error("FirmwareUpgrade state should never be reached")
	return false
end

function M.exit(runtime, transition, dev_idx)
	runtime.log:error("FirmwareUpgrade state should never be reached")
	return true
end

return M
