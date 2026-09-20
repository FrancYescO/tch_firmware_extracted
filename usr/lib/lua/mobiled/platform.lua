---------------------------------
--! @file
--! @brief The platform module giving access to platform specific methods
---------------------------------

local type = type
local runtime, plugin

local M = {}

function M.get_capabilities()
	local capabilities = {
		module_power_control = false,
		antenna_selection = false
	}
	if plugin then
		if type(plugin.module_power_on) == "function" and type(plugin.module_power_off) == "function" then
			capabilities['module_power_control'] = true
		end
		if type(plugin.select_antenna) == "function" then
			capabilities['antenna_selection'] = true
		end
	end
	return capabilities
end

function M._ubus_get_capabilities(req, msg)
	runtime.ubus:reply(req, M.get_capabilities())
end

function M.get_ubus_methods()
	local ubus_methods = {
		['mobiled.platform'] = { capabilities = { M._ubus_get_capabilities, {} } }
	}
	return ubus_methods
end

function M.init(rt)
	runtime = rt
	local status, m = pcall(require, "libplatform")
	plugin = status and m or nil
	local capabilities = M.get_capabilities()
	if capabilities.module_power_control then
		M.module_power_on = plugin.module_power_on
		M.module_power_off = plugin.module_power_off
	end
	if capabilities.antenna_selection then
		M.select_antenna = plugin.select_antenna
	end
end

return M
