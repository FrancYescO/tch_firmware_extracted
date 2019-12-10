local helper = require("mobiled.scripthelpers")

local M = {}

function M.add_error(device, severity, error_type, data)
	if not device.errors then device.errors = {} end

	local uptime = helper.uptime()
	local error = {
		severity = severity,
		type = error_type,
		data = data,
		uptime = uptime
	}
	table.insert(device.errors, error)
	if #device.errors > 20 then
		table.remove(device.errors, 1)
	end
end

return M