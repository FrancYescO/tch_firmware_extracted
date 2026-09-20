local M = {}

function M.entry(runtime, dev_idx)
	runtime.log:notice("FirmwareUpgrade-> Entry Function")
	return true
end

function M.exit(runtime, transition, dev_idx)
	runtime.log:notice("FirmwareUpgrade-> Exit Function")
	return true
end

return M
