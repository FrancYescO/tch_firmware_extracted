local M = {}

local signal_quality_diff_since_uptime

function M.getUptime(conn)
	local data = conn:call("system", "info", {})
	if data then
		return tonumber(data.uptime)
	end
end

function M.setSignalQualityDiffSinceUptime(uptime)
	signal_quality_diff_since_uptime = uptime
end

function M.getSignalQualityDiffSinceUptime()
	return signal_quality_diff_since_uptime
end

return M
