local M = {}

M.SenseEventSet = {}

function M.check(runtime, event, dev_idx)
	runtime.log:error("FirmwareUpgrade state should never be reached")
	return "Error"
end

return M
