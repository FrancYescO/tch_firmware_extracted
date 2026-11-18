---------------------------------
--! @file
--! @brief The platform module giving access to platform specific methods
---------------------------------

local pairs = pairs
local runtime, plugin

local M = {}

function M.get_capabilities()
	if plugin then
		return plugin.get_platform_capabilities()
	end
	return {}
end

function M.get_linked_antenna_controls(device)
	local controls = {}
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.antenna_controls then
			for _, antenna_control in pairs(info.antenna_controls) do
				if antenna_control.linked_device.dev_desc == device.desc then
					table.insert(controls, antenna_control)
				end
			end
		end
	end
	return controls
end

function M.get_linked_power_control(device)
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.power_controls then
			for _, power_control in pairs(info.power_controls) do
				if power_control.linked_device.dev_desc == device.desc then
					return power_control
				end
			end
		end
	end
end

function M.sim_hotswap_supported(device)
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.sim_hotswap then
			for _, sim_hotswap in pairs(info.sim_hotswap) do
				if sim_hotswap.linked_device.dev_desc == device.desc then
					return true
				end
			end
		end
	end
	return false
end

function M.power_all_on()
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.power_controls then
			for _, power_control in pairs(info.power_controls) do
				power_control.power_on()
			end
		end
	end
end

function M.power_all_off()
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.power_controls then
			for _, power_control in pairs(info.power_controls) do
				power_control.power_off()
			end
		end
	end
end

local function ubus_get_capabilities(req, msg)
	local capabilities = {}
	if plugin then
		local info = plugin.get_platform_capabilities()
		if info and info.power_controls then
			capabilities.power_controls = {}
			for _, power_control in pairs(info.power_controls) do
				table.insert(capabilities.power_controls, { linked_device = power_control.linked_device, id = power_control.id })
			end
		end
		if info and info.antenna_controls then
			capabilities.antenna_controls = {}
			for _, antenna_control in pairs(info.antenna_controls) do
				table.insert(capabilities.antenna_controls, { linked_device = antenna_control.linked_device, detector_type = antenna_control.detector_type, id = antenna_control.id, name = antenna_control.name })
			end
		end
		if info and info.sim_hotswap then
			capabilities.sim_hotswap = info.sim_hotswap
		end
	end
	runtime.ubus:reply(req, capabilities)
end

local function ubus_get_info(req, msg)
	local info = {}
	if plugin then
		local platform_info = plugin.get_platform_capabilities()
		if platform_info and platform_info.power_controls then
			info.power_controls = {}
			for _, power_control in pairs(platform_info.power_controls) do
				table.insert(info.power_controls, { current_power_state = power_control.power_state(), id = power_control.id })
			end
		end
		if platform_info and platform_info.antenna_controls then
			info.antenna_controls = {}
			for _, antenna_control in pairs(platform_info.antenna_controls) do
				local antenna_info = {
					current_antenna = antenna_control.antenna_state(),
					id = antenna_control.id,
					auto_selected_antenna = antenna_control.auto_selected_antenna
				}
				if antenna_control.external_detected then
					antenna_info.external_detected = antenna_control.external_detected()
				end
				table.insert(info.antenna_controls, antenna_info)
			end
		end
	end
	runtime.ubus:reply(req, info)
end

function M.get_ubus_methods()
	local ubus_methods = {
		['mobiled.platform'] = {
			capabilities = { ubus_get_capabilities, {} },
			get = { ubus_get_info, {} }
		}
	}
	return ubus_methods
end

function M.init(rt)
	runtime = rt
	local status, m = pcall(require, "libplatform")
	plugin = status and m or nil
	if plugin and plugin.init then
		plugin.init()
	end

	local capabilities = M.get_capabilities()
	if capabilities then
		if capabilities.module_power_control then
			M.module_power_on = plugin.module_power_on
			M.module_power_off = plugin.module_power_off
		end
		if capabilities.antenna_selection then
			M.select_antenna = plugin.select_antenna
		end
	end
end

return M
