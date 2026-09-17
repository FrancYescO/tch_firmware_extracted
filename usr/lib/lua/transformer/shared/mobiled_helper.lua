local M = {}
local helper = require("mobiled.scripthelpers")

local dataMaxAge = {}

function M.setDataMaxAge(dev_idx, age)
	dataMaxAge[dev_idx] = age
end

function M.getDataMaxAge(dev_idx)
	return dataMaxAge[dev_idx]
end

function M.getUbusInfoUseCellularInterfaceKey(ubus_connection, ubus_command, ubus_parameter, key)
	local max_age = 5

	local dev_idx = tonumber(string.match(key,'^cellular_interface_(%d+)$'))
	if not dev_idx then
		local info = ubus_connection:call("mobiled.device", "get", {imei = key})
		dev_idx = info.dev_idx
		if not dev_idx then return nil end
	end

	return helper.getUbusData(ubus_connection, ubus_command, ubus_parameter, { dev_idx = dev_idx, max_age = max_age })
end

return M
