local failoverhelper = require("wansensingfw.failoverhelper")

local M = {}

M.SenseEventSet = {
    'wansensing_reload',
    'mobiled_device_1_initialized',
}

function M.check(runtime)
	local cursor = runtime.uci.cursor()
	if not cursor then
		return "Mobile"
	end

	local primary_wan_mode = cursor:get("wansensing", "global", "primarywanmode")
	if primary_wan_mode and primary_wan_mode:upper() == "MOBILE" then
		failoverhelper.mobiled_enable(runtime, "1", "wwan")
		return "Mobile"
	end

	return "L2Sense"
end

return M
